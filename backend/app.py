from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_bcrypt import Bcrypt
import psycopg2
import uuid
import json
import datetime
from decimal import Decimal
import re

from langchain_community.utilities import SQLDatabase
from langchain.chains import create_sql_query_chain
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents import create_react_agent, AgentExecutor
from langchain.tools import Tool
from langchain_community.tools import QuerySQLDataBaseTool
from langchain_core.prompts import ChatPromptTemplate
from langchain_groq import ChatGroq
from dotenv import load_dotenv
import os

load_dotenv() # Load environment variables from .env file

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

load_dotenv()
db_uri = os.getenv("DB_URI")

def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        port=os.getenv("DB_PORT")
    )

llm = ChatGroq(
    model_name="llama-3.3-70b-versatile",
    temperature=0,
    groq_api_key=os.getenv("GROQ_API_KEY")
)

db = SQLDatabase.from_uri(db_uri)

EXPENSE_CATEGORIES = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others']
INCOME_CATEGORIES = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others']


SQL_PROMPT_TEMPLATE = """You are a PostgreSQL expert. Your sole purpose is to generate a single, syntactically correct PostgreSQL query to answer the user's question.
- **DO NOT** add any explanation or markdown formatting.
- **ONLY** output the raw SQL query.
- If the question asks for a summary, total, or statistics, use appropriate SQL aggregations like SUM(), COUNT(), and GROUP BY.

Here is the table info: {table_info}
You can use the following number of examples for each table: {top_k}

Question: {input}
SQL Query:"""

sql_prompt = ChatPromptTemplate.from_template(SQL_PROMPT_TEMPLATE)
sql_query_chain = create_sql_query_chain(llm, db, prompt=sql_prompt)
execute_query = QuerySQLDataBaseTool(db=db)

ANSWER_PROMPT = ChatPromptTemplate.from_template(
    "Given the user question, corresponding SQL query, and SQL result, answer the user question in a natural, friendly tone.\n"
    "IMPORTANT: ALWAYS format any monetary amounts using the Indian Rupee symbol (₹). DO NOT use the dollar sign ($) or the word 'dollars'.\n\n"
    "Question: {question}\n"
    "SQL Query: {query}\n"
    "SQL Result: {result}\n"
    "Answer:"
)

def run_sql_query_tool(question: str):
    user_id = request.get_json().get('user_id')
    if not user_id: return "Error: Could not determine the user ID."
    
    # Securely append the user_id context to ensure the LLM ALWAYS filters by the current user
    secure_question = f"{question}\nCRITICAL INSTRUCTION: You MUST filter the WHERE clause to ONLY include rows where user_id = '{user_id}'."
    
    sql_query_response = sql_query_chain.invoke({"question": secure_question})
    match = re.search(r"SELECT.*", sql_query_response, re.DOTALL | re.IGNORECASE)
    if not match: return "I could not generate a valid SQL query for that question."
    cleaned_query = match.group(0).strip().replace(";", "")
    print(f"--- Executing Cleaned SQL: ---\n{cleaned_query}\n-----------------------------")
    
    # Execute SQL
    db_result = execute_query.invoke(cleaned_query)
    
    # Summarize Result
    summarizer_chain = ANSWER_PROMPT | llm
    summary = summarizer_chain.invoke({
        "question": question,
        "query": cleaned_query,
        "result": db_result
    })
    return summary.content

financial_history_tool = Tool(
    name="financial_history_db",
    func=run_sql_query_tool,
    description="""
Use ONLY when the user asks about:
- spending
- expenses
- income
- balance
- transactions
- financial history

DO NOT use for greetings, casual conversation, or general questions.
"""
)

planner_prompt = ChatPromptTemplate.from_template("""
    You are a helpful financial assistant. Provide actionable advice for the following question:
    Question: {question}
    Use this data: {data}
    Provide a clear, step-by-step plan or a concise summary.
""")
planner_chain = planner_prompt | llm
def financial_planner(input_str: str):
    parts = input_str.split('|')
    question, data = (parts[0], parts[1]) if len(parts) > 1 else (parts[0], "")
    return planner_chain.invoke({"question": question, "data": data})
financial_planning_tool = Tool(
    name="financial_planner",
    func=financial_planner,
    description="Use this for planning, scheduling, and advice questions. Use AFTER gathering data. Input must be 'question | data'."
)

def add_transaction_func(action_input: str) -> str:
    """The function that the AI agent will call to add a transaction."""
    try:
        params = json.loads(action_input)
        user_id = request.get_json().get('user_id')
        if not user_id: return "Error: Could not determine the user ID for this operation."

        # Ensure category is strictly from the allowed list
        trans_type = params.get('transaction_type', 'Expense').capitalize()
        raw_category = params.get('category', 'Others')
        
        def match_category(cat, allowed):
            cat_lower = cat.lower()
            for a in allowed:
                if cat_lower == a.lower():
                    return a
            
            # Fuzzy match common words to handle agent edge cases
            if trans_type == 'Expense':
                if any(w in cat_lower for w in ['movie', 'ticket', 'entertainment', 'show']): return 'Shopping'
                if any(w in cat_lower for w in ['uber', 'taxi', 'train', 'flight', 'bus', 'cab']): return 'Travel'
                if any(w in cat_lower for w in ['electric', 'water', 'internet', 'phone', 'wifi']): return 'Bills'
                if any(w in cat_lower for w in ['restaurant', 'coffee', 'grocery', 'snack', 'drink', 'dinner', 'lunch', 'breakfast']): return 'Food'
            
            return 'Others'

        if trans_type == 'Expense':
            raw_category = match_category(raw_category, EXPENSE_CATEGORIES)
        elif trans_type == 'Income':
            raw_category = match_category(raw_category, INCOME_CATEGORIES)
        else:
            trans_type = 'Expense'
            raw_category = 'Others'

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO transactions (transaction_id, user_id, title, description, amount, category, transaction_type, date) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (str(uuid.uuid4()), user_id, params['title'], params.get('description'), params['amount'], raw_category, trans_type, datetime.datetime.fromisoformat(params.get('date')) if params.get('date') else datetime.datetime.now())
        )
        conn.commit()
        cur.close()
        conn.close()
        return f"Successfully added the transaction for '{params['title']}'."
    except json.JSONDecodeError: return "Error: The input was not valid JSON. Please provide transaction details in the correct format."
    except Exception as e: return f"Error: Failed to add the transaction to the database. Details: {e}"

add_transaction_tool = Tool(
    name="add_transaction_db",
    func=add_transaction_func,
    description=f"""
    Use this tool to add a new income or expense transaction to the database based on the user's request.
    The input MUST be a single valid JSON string.

    The JSON object must have the following keys:
    - 'title': (string) A concise title for the transaction.
    - 'amount': (number) The numerical amount of the transaction.
    - 'category': (string) The category of the transaction.
    - 'transaction_type': (string) Either 'Income' or 'Expense'.
    - 'description': (string, optional) Any extra notes from the user.
    - 'date': (string, optional) A specific ISO format date (e.g. "2024-07-30"). If not provided, current date will be used.

    **RULES FOR CATEGORIES:**
    1. For ANY transaction, you MUST classify it strictly into one of the provided categories.
    2. EXPENSE_CATEGORIES = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others']
    3. INCOME_CATEGORIES = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others']
    4. DO NOT invent new categories. You must intelligently map the user's request to the CLOSEST matching category from the lists above. If it absolutely cannot be mapped, use 'Others'.

    Example User Request: "add an expense of 15 dollars for coffee with my friends"
    Correct Action Input: {{"title": "Coffee", "amount": 15.00, "category": "Food", "transaction_type": "Expense", "description": "Met with my friends"}}
    """
)

# --- Create the Agent ---
tools = [financial_history_tool, financial_planning_tool, add_transaction_tool]
agent_prompt = ChatPromptTemplate.from_template("""
You are a helpful financial assistant. You have access to tools.
Always filter database queries by the user_id: {user_id}
Today's Date/Time is: {current_date}
If the user asks for a summary, stats, or an overview, use the financial_history_db tool to query aggregated data (e.g., total expenses, income by category) for their user_id.

IMPORTANT CRITICAL RULE: The currency used by the user is the Indian Rupee (₹). You MUST NEVER output monetary amounts using the dollar sign ($) or the word "dollars". Always use "₹" before the amount (e.g., ₹500).

Tools:
{tools}
Use the following format:
Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this can repeat)
Thought: I now know the final answer
Final Answer: the final answer to the original input question
Begin!
Question: {input}
Thought:{agent_scratchpad}
""")
agent = create_react_agent(llm, tools, agent_prompt)
agent_executor = AgentExecutor(
    agent=agent,
    tools=tools,
    verbose=True,
    handle_parsing_errors=True,
    max_iterations=3
)
# ==============================================================================
# 4. API ENDPOINTS
# ==============================================================================
@app.route('/')
def home(): return "FinManager API is running."

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    user_id = str(uuid.uuid4())
    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT user_id FROM customers WHERE email = %s", (data['email'],))
        if cur.fetchone(): return jsonify({"status": "error", "message": "User with this email already exists"}), 409
        cur.execute(
            "INSERT INTO customers (user_id, name, email, password, phone_no) VALUES (%s, %s, %s, %s, %s)",
            (user_id, data['name'], data['email'], hashed_password, data.get('phone_no'))
        )
        conn.commit()
        return jsonify({"status": "success", "message": "User registered successfully", "user_id": user_id}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn: cur.close(); conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT user_id, name, password, phone_no FROM customers WHERE email = %s", (data['email'],))
        user = cur.fetchone()
        if user:
            user_id, name, stored_hash, phone_no = user
            if bcrypt.check_password_hash(stored_hash, data['password']):
                return jsonify({
                    "status": "success", "message": "Login successful",
                    "user_id": user_id, "name": name, "phone_no": phone_no, "email": data['email']
                })
        return jsonify({"status": "error", "message": "Invalid email or password"}), 401
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn: cur.close(); conn.close()

@app.route('/transaction', methods=['POST'])
def add_transaction():
    data = request.get_json()
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO transactions (transaction_id, user_id, title, description, amount, category, transaction_type, date) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (str(uuid.uuid4()), data['user_id'], data['title'], data.get('description'), data['amount'], data['category'], data['transaction_type'], data['date'])
        )
        conn.commit()
        return jsonify({"status": "success", "message": "Transaction added successfully"}), 201
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn: cur.close(); conn.close()

@app.route('/transactions/<user_id>', methods=['GET'])
def get_transactions(user_id):
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT transaction_id, title, description, amount, category, transaction_type, date FROM transactions WHERE user_id = %s ORDER BY date DESC", (user_id,))
        rows = cur.fetchall()
        transactions = [{
            "transaction_id": row[0], "title": row[1], "description": row[2],
            "amount": float(row[3]) if isinstance(row[3], Decimal) else row[3],
            "category": row[4], "transaction_type": row[5], "date": row[6].isoformat()
        } for row in rows]
        return jsonify({"status": "success", "transactions": transactions})
    except Exception as e: return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        if conn: cur.close(); conn.close()

@app.route('/ai/agent/invoke', methods=['POST'])
def ai_agent_invoke():
    data = request.get_json()

    user_id = data.get('user_id')
    user_question = data.get('question', '').strip()

    current_date = data.get('current_date', datetime.datetime.now().isoformat())

    if not all([user_id, user_question]):
        return jsonify({
            "status": "error",
            "message": "user_id and question are required"
        }), 400

    greetings = {
        "hi",
        "hello",
        "hey",
        "good morning",
        "good evening",
        "good afternoon"
    }

    if user_question.lower() in greetings:
        return jsonify({
            "status": "success",
            "answer": "Hello! How can I help manage your finances today?"
        })

    try:
        result = agent_executor.invoke({
            "input": user_question,
            "user_id": user_id,
            "current_date": current_date
        })

        return jsonify({
            "status": "success",
            "answer": result["output"]
        })

    except Exception as e:
        print(f"Agent execution failed: {e}")
        return jsonify({
            "status": "error",
            "message": "The AI agent encountered a problem. Please try rephrasing."
        }), 500
    

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)