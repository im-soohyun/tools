from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/internal-api', methods=['GET', 'POST'])
def internal_api():
    return jsonify({"message": "!! SSRF OK !!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8282)
