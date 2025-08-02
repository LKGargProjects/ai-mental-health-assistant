# Deployment Guide

## Single Codebase Deployment

This application is designed to run on Docker and Render only. No local Flask development is supported.

## Docker Deployment

### Prerequisites
- Docker Desktop installed and running
- Docker Compose v2+

### Local Docker Testing
```bash
# Build and start single container with external services
docker-compose -f docker-compose.single.yml up --build

# Access the application
# Single Container: http://localhost:8080 (Flutter Web + API)
# Direct API: http://localhost:5055 (Flask API only)
# Database: localhost:5432
# Redis: localhost:6379
```

### Environment Variables
Copy `env.example` to `.env` and configure:
- `GEMINI_API_KEY`: Your Gemini API key
- `OPENAI_API_KEY`: Your OpenAI API key (optional)
- `PPLX_API_KEY`: Your Perplexity API key (optional)

## Render Deployment

### Single Container Service
1. Connect your GitHub repository to Render
2. Create a new Web Service
3. Configure:
   - **Build Command**: `docker build -t ai-buddy-app .`
   - **Start Command**: `docker run -p $PORT:80 ai-buddy-app`
   - **Environment**: Docker

### Environment Variables (Render)
Set these in Render dashboard:
```
PORT=10000
SECRET_KEY=your-production-secret-key
GEMINI_API_KEY=your-gemini-api-key
OPENAI_API_KEY=your-openai-api-key
PPLX_API_KEY=your-perplexity-api-key
AI_PROVIDER=gemini
ENVIRONMENT=production
RENDER=true
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379
```

### Database (Render)
- Use Render's PostgreSQL service
- Set `DATABASE_URL` environment variable

## Health Checks

The application includes health checks:
- Backend: `GET /api/health`
- Flutter Web: `GET /health`

## Monitoring

- Backend metrics: `GET /api/metrics`
- Health status: `GET /api/health`

## Troubleshooting

### Common Issues
1. **Docker not running**: Start Docker Desktop
2. **Port conflicts**: Check if ports 5055, 8080, 5432, 6379 are available
3. **API key issues**: Verify environment variables are set correctly
4. **Database connection**: Ensure PostgreSQL is running and accessible

### Logs
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs backend
docker-compose logs flutter-web
``` 