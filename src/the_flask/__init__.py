from flask import Flask

app = Flask(__name__)


def hello():
    return "this is hello"


@app.route("/")
def hello_world():
    return "<p>Hello world</p>"
