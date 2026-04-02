import os

from flask import jsonify
from app import app
from app import db
from app.models import Menu

@app.route('/')
def home():
	return jsonify({ "status": "ok" })

@app.route('/version')
def version():
	return jsonify({
		"app_version": os.environ.get("APP_VERSION", "unknown"),
		"app_semver": os.environ.get("APP_SEMVER", "unknown"),
		"git_commit_short": os.environ.get("GIT_COMMIT_SHORT", "unknown"),
	})

@app.route('/menu')
def menu():
    today = Menu.query.first()
    if today:
        body = { "today_special": today.name }
        status = 200
    else:
        body = { "error": "Sorry, the service is not available today." }
        status = 404
    return jsonify(body), status