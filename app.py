"""
Flask Web Application with Azure SQL Database
"""
import os
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import logging
from urllib.parse import quote_plus

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Database configuration
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'appdb')
DB_USER = os.environ.get('DB_USER', 'adminuser')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_PORT = os.environ.get('DB_PORT', '1433')
DB_TYPE = os.environ.get('DB_TYPE', 'mssql')

# Construct database URI for MSSQL
params = quote_plus(
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={DB_HOST},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};"
    f"PWD={DB_PASSWORD};"
    f"Encrypt=yes;"
    f"TrustServerCertificate=no;"
    f"Connection Timeout=30;"
)
DATABASE_URI = f'mssql+pyodbc:///?odbc_connect={params}'

app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Database Models
class HealthCheck(db.Model):
    """Health check model to verify database connectivity"""
    __tablename__ = 'health_checks'

    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(50))

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat(),
            'status': self.status
        }

class Item(db.Model):
    """Sample item model"""
    __tablename__ = 'items'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'created_at': self.created_at.isoformat()
        }

# Routes
@app.route('/')
def index():
    """Root endpoint"""
    return jsonify({
        'message': 'Flask App with Azure PostgreSQL',
        'status': 'running',
        'endpoints': {
            'health': '/health',
            'items': '/items',
            'items_create': '/items (POST)'
        }
    })

@app.route('/health')
def health():
    """Health check endpoint with database connectivity test"""
    try:
        # Test database connection
        db.session.execute(db.text('SELECT 1'))

        # Log health check
        health_check = HealthCheck(status='healthy')
        db.session.add(health_check)
        db.session.commit()

        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@app.route('/items', methods=['GET'])
def get_items():
    """Get all items"""
    try:
        items = Item.query.all()
        return jsonify({
            'items': [item.to_dict() for item in items],
            'count': len(items)
        }), 200
    except Exception as e:
        logger.error(f"Error fetching items: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/items', methods=['POST'])
def create_item():
    """Create a new item"""
    try:
        data = request.get_json()

        if not data or 'name' not in data:
            return jsonify({'error': 'Name is required'}), 400

        item = Item(
            name=data['name'],
            description=data.get('description', '')
        )

        db.session.add(item)
        db.session.commit()

        return jsonify({
            'message': 'Item created successfully',
            'item': item.to_dict()
        }), 201
    except Exception as e:
        logger.error(f"Error creating item: {str(e)}")
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/items/<int:item_id>', methods=['GET'])
def get_item(item_id):
    """Get a specific item by ID"""
    try:
        item = Item.query.get_or_404(item_id)
        return jsonify(item.to_dict()), 200
    except Exception as e:
        logger.error(f"Error fetching item {item_id}: {str(e)}")
        return jsonify({'error': str(e)}), 404

@app.before_request
def before_request():
    """Create tables before first request"""
    try:
        db.create_all()
    except Exception as e:
        logger.error(f"Error creating tables: {str(e)}")

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)
