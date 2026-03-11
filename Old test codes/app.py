from flask import Flask, jsonify, render_template
from flask_cors import CORS

app = Flask(__name__)
CORS(app) # Vital for React compatibility later

# This dictionary is shared between the background thread and the web routes
bike_state = {
    "speed": 0,
    "distance": 0,
    "smoke_detected": False,
    "sensors_ok": False
}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/data')
def get_data():
    return jsonify(bike_state)
