# ==============================================================================
# 1. IMPORTS
# ==============================================================================
# --- Core Flask and Database Imports ---
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_bcrypt import Bcrypt
import psycopg2
import uuid
import json
import datetime
from decimal import Decimal
import os
import re # For cleaning up AI-generated SQL

# --- LangChain and AI Imports ---
from langchain_community.utilities import SQLDatabase
from langchain.chains import create_sql_query_chain
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents import create_react_agent, AgentExecutor
from langchain.tools import Tool
from langchain_community.tools import QuerySQLDataBaseTool
from langchain_core.prompts import ChatPromptTemplate
from dotenv import load_dotenv

# ==============================================================================
# 2. INITIAL SETUP & CONFIGURATION
# ==============================================================================
load_dotenv() # Load environment variables from .env file

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

# --- Database Connection Function ---
def get_db_connection():
    return psycopg2.connect(
        host="finmanager.cypg4giyk1os.us-east-1.rds.amazonaws.com",
        database="finmanager",
        user="postgres",
        password="duveen2546R",  
        port=5432
    )

# ==============================================================================
# 3. LANGCHAIN AI AGENT SETUP (Using Google Gemini)
# ==============================================================================

# This code relies on the GOOGLE_API_KEY being set from the .env file
llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash-latest", 
    temperature=0, 
    convert_system_message_to_human=True
)

db_uri = "postgresql+psycopg2://postgres:duveen2546R@finmanager.cypg4giyk1os.us-east-1.rds.amazonaws.com:5432/finmanager"
db = SQLDatabase.from_uri(db_uri)

# --- Define the official category lists ---
EXPENSE_CATEGORIES = ['Food', 'Travel', 'Bills', 'Shopping', 'Rent', 'Others']
INCOME_CATEGORIES = ['Salary', 'Bonus', 'Gift', 'Investment', 'Others']

# --- Define Agent Tools ---

# Tool 1: For querying transaction history
# --- CRITICAL FIX: Add the {top_k} variable to the prompt template ---
SQL_PROMPT_TEMPLATE = """You are a PostgreSQL expert. Your sole purpose is to generate a single, syntactically correct PostgreSQL query to answer the user's question.
- **DO NOT** add any explanation or markdown formatting.
- **ONLY** output the raw SQL query.

Here is the table info: {table_info}
You can use the following number of examples for each table: {top_k}

Question: {input}
SQL Query:"""

sql_prompt = ChatPromptTemplate.from_template(SQL_PROMPT_TEMPLATE)
sql_query_chain = create_sql_query_chain(llm, db, prompt=sql_prompt)
# --- END OF FIX ---
execute_query = QuerySQLDataBaseTool(db=db)

def run_sql_query_tool(question: str):
    sql_query_response = sql_query_chain.invoke({"question": question})
    match = re.search(r"SELECT.*", sql_query_response, re.DOTALL | re.IGNORECASE)
    if not match: return "I could not generate a valid SQL query for that question."
    cleaned_query = match.group(0).strip().replace(";", "")
    print(f"--- Executing Cleaned SQL: ---\n{cleaned_query}\n-----------------------------")
    return execute_query.invoke(cleaned_query)

financial_history_tool = Tool(
    name="financial_history_db",
    func=run_sql_query_tool,
    description="Use this tool to find information about a user's past financial transactions. Input should be a natural language question."
)

# Tool 2: For financial advice and planning
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

# Tool 3: For adding new transactions
def add_transaction_func(action_input: str) -> str:
    """The function that the AI agent will call to add a transaction."""
    try:
        params = json.loads(action_input)
        user_id = agent_prompt.partial_variables.get('user_id')
        if not user_id: return "Error: Could not determine the user ID for this operation."

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO transactions (transaction_id, user_id, title, description, amount, category, transaction_type, date) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            (str(uuid.uuid4()), user_id, params['title'], params.get('description'), params['amount'], params['category'], params['transaction_type'], datetime.datetime.fromisoformat(params.get('date')) if params.get('date') else datetime.datetime.now())
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
    1. If the 'transaction_type' is 'Expense', you MUST choose the 'category' from this EXACT list: {EXPENSE_CATEGORIES}.
    2. If the 'transaction_type' is 'Income', you MUST choose the 'category' from this EXACT list: {INCOME_CATEGORIES}.
    3. If the user's request is ambiguous or does not fit any category, you MUST use 'Others'. DO NOT invent new categories.

    Example User Request: "add an expense of 15 dollars for coffee with my friends"
    Correct Action Input: {{"title": "Coffee", "amount": 15.00, "category": "Food", "transaction_type": "Expense", "description": "Met with my friends"}}
    """
)

# --- Create the Agent ---
tools = [financial_history_tool, financial_planning_tool, add_transaction_tool]
agent_prompt = ChatPromptTemplate.from_template("""
You are a helpful financial assistant. You have access to tools.
Always filter database queries by the user_id: {user_id}
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
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

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
        cur.execute("SELECT user_id FROM users WHERE email = %s", (data['email'],))
        if cur.fetchone(): return jsonify({"status": "error", "message": "User with this email already exists"}), 409
        cur.execute(
            "INSERT INTO users (user_id, name, email, password, phone_no) VALUES (%s, %s, %s, %s, %s)",
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
        cur.execute("SELECT user_id, name, password, phone_no FROM users WHERE email = %s", (data['email'],))
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
    user_question = data.get('question')
    if not all([user_id, user_question]):
        return jsonify({"status": "error", "message": "user_id and question are required"}), 400
    try:
        agent_prompt.partial_variables['user_id'] = user_id
        result = agent_executor.invoke({"input": user_question, "user_id": user_id})
        return jsonify({"status": "success", "answer": result['output']})
    except Exception as e:
        print(f"Agent execution failed: {e}")
        return jsonify({"status": "error", "message": "The AI agent encountered a problem. Please try rephrasing."}), 500

# ==============================================================================
# 5. RUN THE APP
# ==============================================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)