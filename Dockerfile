# Use official Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install -U python-dotenv

# Copy project files
COPY . .

# Expose port (Flask default is 5000)
EXPOSE 5000

# Start the app with Gunicorn for production
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
