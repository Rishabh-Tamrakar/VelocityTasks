# VelocityTasks ⚡

> **Lightning-fast task management for the modern developer**

VelocityTasks is a lightweight, high-performance task management web application designed specifically to run on [FeatherJet](https://github.com/Rishabh-Tamrakar/FeatherJet), the ultra-lightweight Java web server. Built with simplicity, speed, and elegance in mind.

![VelocityTasks Screenshot](docs/screenshot.png)

## 🌟 Features

### ⚡ **Lightning Fast**
- Optimized for FeatherJet's lightweight architecture
- Minimal resource footprint (~15MB total)
- Sub-second response times
- Progressive Web App (PWA) capabilities

### 🎨 **Modern UI/UX**
- Clean, intuitive interface
- Responsive design (mobile-first)
- Real-time updates
- Smooth animations and transitions
- Dark/light theme support (coming soon)

### 📋 **Task Management**
- Create, read, update, delete tasks (CRUD)
- Priority levels (High, Medium, Low)
- Task completion tracking
- Real-time statistics
- Search and filter functionality

### 🔧 **Developer Friendly**
- RESTful API design
- JSON responses
- CORS enabled
- Comprehensive logging
- Easy to extend

## 🏗️ Architecture

VelocityTasks follows a clean, layered architecture:

```
┌─────────────────┐
│   Frontend      │  Modern HTML5/CSS3/JavaScript
│   (Web UI)      │  Progressive Web App
├─────────────────┤
│   API Layer     │  RESTful servlets
│   (Servlets)    │  JSON responses
├─────────────────┤
│   Business      │  Task management logic
│   Logic         │  In-memory data store
├─────────────────┤
│   FeatherJet    │  Lightweight web server
│   (Runtime)     │  Servlet container
└─────────────────┘
```

## 📋 Prerequisites

- **Java 17** or higher
- **Maven 3.6+** (for building)
- **FeatherJet 1.0+** (web server)
- Modern web browser (Chrome, Firefox, Safari, Edge)

## 🚀 Quick Start

### 1. Clone and Build

```bash
git clone <your-repo-url>
cd velocity-tasks
mvn clean package
```

### 2. Deploy to FeatherJet

```bash
# Copy the WAR file to FeatherJet webapps directory
cp target/velocity-tasks.war /path/to/featherjet/webapps/

# Or extract as a directory
cd /path/to/featherjet/webapps/
unzip velocity-tasks.war -d velocity-tasks/
```

### 3. Start FeatherJet

```bash
cd /path/to/featherjet
java -jar featherjet-server.jar
```

### 4. Access the Application

Open your browser and navigate to:
- **http://localhost:8080/velocity-tasks/** (if deployed as WAR)
- **http://localhost:8080/** (if deployed as ROOT application)

## 🛠️ Configuration

### FeatherJet Configuration

Edit `conf/server.properties`:

```properties
# Server Settings
server.port=8080
server.host=0.0.0.0
server.maxThreads=200

# Performance Tuning for VelocityTasks
server.connectionTimeout=30000
server.maxConnections=1000
server.staticContent.cache=true
server.staticContent.cacheSize=50MB
```

### Application Configuration

VelocityTasks uses sensible defaults and requires no additional configuration. All settings are handled through the web interface.

## 📊 API Documentation

### Task Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/tasks` | Get all tasks |
| `POST` | `/api/tasks` | Create new task |
| `GET` | `/api/tasks/{id}` | Get specific task |
| `PUT` | `/api/tasks/{id}` | Update task |
| `DELETE` | `/api/tasks/{id}` | Delete task |

### Statistics Endpoint

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/stats` | Get application statistics |

### Example Request/Response

**Create Task:**
```bash
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Complete project documentation",
    "priority": "HIGH"
  }'
```

**Response:**
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "title": "Complete project documentation",
  "priority": "HIGH",
  "completed": false,
  "createdAt": "2025-01-20T10:30:00",
  "updatedAt": "2025-01-20T10:30:00"
}
```

## 🐧 Linux Server Deployment

### Systemd Service Setup

1. **Create service file:**

```bash
sudo nano /etc/systemd/system/velocity-tasks.service
```

```ini
[Unit]
Description=VelocityTasks on FeatherJet
After=network.target

[Service]
Type=simple
User=featherjet
Group=featherjet
WorkingDirectory=/opt/featherjet
ExecStart=/usr/bin/java -Xms256m -Xmx512m -jar featherjet-server.jar
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

2. **Enable and start service:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable velocity-tasks
sudo systemctl start velocity-tasks
```

### Nginx Reverse Proxy (Optional)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Deployment

```dockerfile
FROM openjdk:17-jre-slim

WORKDIR /app
COPY featherjet/ .
COPY velocity-tasks.war webapps/ROOT.war

EXPOSE 8080
CMD ["java", "-jar", "featherjet-server.jar"]
```

```bash
docker build -t velocity-tasks .
docker run -p 8080:8080 velocity-tasks
```

## 🔧 Development Setup

### Local Development

1. **Start with Maven Jetty plugin:**
```bash
mvn jetty:run
```

2. **Or build and deploy to local FeatherJet:**
```bash
mvn clean package
cp target/*.war /path/to/featherjet/webapps/
```

### Project Structure

```
velocity-tasks/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/velocitytasks/
│   │   │       ├── model/           # Data models
│   │   │       ├── service/         # Business logic
│   │   │       └── servlet/         # REST endpoints
│   │   └── webapp/
│   │       ├── WEB-INF/
│   │       │   └── web.xml          # Servlet configuration
│   │       ├── css/                 # Stylesheets
│   │       ├── js/                  # JavaScript
│   │       ├── images/              # Images and icons
│   │       ├── error/               # Error pages
│   │       └── index.html           # Main application
│   └── test/                        # Unit tests
├── pom.xml                          # Maven configuration
└── README.md                        # This file
```

## 📈 Performance Optimization

### JVM Tuning

```bash
java -Xms512m -Xmx1g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:+PrintGC \
     -jar featherjet-server.jar
```

### FeatherJet Tuning

```properties
# Increase thread pool for high concurrency
server.maxThreads=400
server.minThreads=50

# Enable compression
server.compression.enabled=true
server.compression.minSize=1024

# Static content caching
server.staticContent.cache=true
server.staticContent.cacheSize=100MB
server.staticContent.maxAge=86400
```

## 🧪 Testing

### Run Tests

```bash
mvn test
```

### Manual Testing

```bash
# Health check
curl http://localhost:8080/api/stats

# Create test task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Task","priority":"HIGH"}'
```

## 🔍 Monitoring & Troubleshooting

### Log Files

- **FeatherJet logs:** `logs/featherjet.log`
- **Access logs:** `logs/access.log`
- **Application logs:** Available through FeatherJet logging

### Common Issues

**Port Already in Use:**
```bash
# Check what's using port 8080
netstat -tlnp | grep :8080
sudo lsof -i :8080
```

**Memory Issues:**
```bash
# Increase heap size
java -Xmx2g -jar featherjet-server.jar
```

**Permission Issues:**
```bash
# Ensure proper permissions
chmod +x bin/startup.sh
chown -R featherjet:featherjet /opt/featherjet
```

## 🚧 Roadmap

- [ ] **v1.1.0**
  - Task categories/tags
  - Due dates and reminders
  - Data export/import

- [ ] **v1.2.0**
  - Multi-user support
  - Authentication & authorization
  - Team collaboration features

- [ ] **v1.3.0**
  - Database persistence (SQLite/H2)
  - Advanced search and filtering
  - REST API versioning

- [ ] **v2.0.0**
  - Microservices architecture
  - Real-time collaboration
  - Mobile app companion

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `mvn test`
6. Commit changes: `git commit -m 'Add amazing feature'`
7. Push to branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **FeatherJet** - The lightning-fast web server that powers VelocityTasks
- **Modern Web Standards** - HTML5, CSS3, ES6+ for the frontend
- **Jakarta EE** - Servlet API for the backend
- **Google Gson** - JSON processing library

## 📞 Support

- 📧 **Email:** [rishabh.tamrakar@protonmail.com](rishabh.tamrakar@protonmail.com)
- 🐛 **Issues:** [GitHub Issues](https://github.com/your-username/velocity-tasks/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/your-username/velocity-tasks/discussions)
- 📖 **Documentation:** [Wiki](https://github.com/your-username/velocity-tasks/wiki)

---

<div align="center">

**VelocityTasks** - *Light as a feather, fast as lightning* ⚡

Made with ❤️ for the developer community

[⭐ Star this project](https://Rishabh-Tamrakar/velocity-tasks) | [🐛 Report Bug](https://github.com/Rishabh-Tamrakar/velocity-tasks/issues) | [💡 Request Feature](https://github.com/your-username/velocity-tasks/issues)

</div>


