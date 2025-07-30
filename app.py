from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_bcrypt import Bcrypt
import psycopg2
import uuid
import json
import datetime
from decimal import Decimal
import os

from langchain_community.utilities import SQLDatabase
from langchain.chains import create_sql_query_chain
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents import create_react_agent, AgentExecutor
from langchain.tools import Tool
from langchain_community.tools import QuerySQLDataBaseTool
from langchain_core.prompts import ChatPromptTemplate

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

def get_db_connection():
    return psycopg2.connect(
        host="localhost",
        database="postgres",
        user="postgres",
        password="duveen2546"
    )

llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash-latest", 
    temperature=0, 
    convert_system_message_to_human=True
)

db_uri = "postgresql+psycopg2://postgres:duveen2546@localhost/postgres"
db = SQLDatabase.from_uri(db_uri)

SQL_PROMPT_TEMPLATE = """You are a PostgreSQL expert. Given an input question, create a syntactically correct PostgreSQL query to run.
Never query for all columns from a table. You must query only the columns that are needed to answer the question.
Pay attention to use only the column names you can see in the table below. Be careful to not query for columns that do not exist.
Also, pay attention to which column is in which table.
Pay attention to use CURRENT_DATE for dates.

Here is the table info: {table_info}
You can use the following number of examples for each table: {top_k}

Question: {input}

SQL Query:"""

sql_prompt = ChatPromptTemplate.from_template(SQL_PROMPT_TEMPLATE)
sql_query_chain = create_sql_query_chain(llm, db, prompt=sql_prompt)
# --- END OF FIX ---

execute_query = QuerySQLDataBaseTool(db=db)

def run_sql_query_tool(question: str):
    """
    This function takes a natural language question, converts it to a SQL query,
    executes it, and returns the result. It includes a cleanup step for safety.
    """
    sql_query = sql_query_chain.invoke({"question": question})
    cleaned_query = sql_query.strip().replace("```sql", "").replace("```", "")
    return execute_query.invoke(cleaned_query)

financial_history_tool = Tool(
    name="financial_history_db",
    func=run_sql_query_tool,
    description="Use this tool to find information about a user's past financial transactions, including expenses and income. Input should be a complete, natural language question."
)

planner_prompt = ChatPromptTemplate.from_template("""
    You are a helpful financial assistant. Your role is to provide actionable advice based on the user's financial data.
    Answer the following question thoughtfully:
    Question: {question}
    Use this data to inform your answer:
    Data: {data}
    Provide a clear, step-by-step plan or a concise summary as your answer.
""")
planner_chain = planner_prompt | llm
def financial_planner(input_str: str):
    parts = input_str.split('|')
    question = parts[0]
    data = parts[1] if len(parts) > 1 else ""
    return planner_chain.invoke({"question": question, "data": data})
financial_planning_tool = Tool(
    name="financial_planner",
    func=financial_planner,
    description="Use this tool for financial planning, scheduling, and advice questions that require reasoning. Use this AFTER gathering data from the financial_history_db tool. The input must be a string formatted as 'The user's original question | The data you found from the database'."
)

tools = [financial_history_tool, financial_planning_tool]
agent_prompt = ChatPromptTemplate.from_template("""
You are a helpful financial assistant. You have access to tools to answer user questions.
Your primary goal is to help the user with their finances.
Always filter database queries by the user_id: {user_id}

Tools:
{tools}

Use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of [{tool_names}]
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

Question: {input}
Thought:{agent_scratchpad}
""")
agent = create_react_agent(llm, tools, agent_prompt)
agent_executor = AgentExecutor(agent=agent, tools=tools, verbose=True)

@app.route('/')
def home():
    return "FinManager API is running."

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
        if cur.fetchone():
            return jsonify({"status": "error", "message": "User with this email already exists"}), 409
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
        result = agent_executor.invoke({"input": user_question, "user_id": user_id})
        return jsonify({"status": "success", "answer": result['output']})
    except Exception as e:
        print(f"Agent execution failed: {e}")
        return jsonify({"status": "error", "message": "The AI agent encountered a problem. Please try rephrasing."}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)