from flask import Flask, escape, request

import sys

print("#" * 80)
print(sys.path)
print("#" * 80)

app = Flask(__name__)


@app.route("/")
def hello():
    name = request.args.get("name", "World")
    return f"Hello, {escape(name)}!"
