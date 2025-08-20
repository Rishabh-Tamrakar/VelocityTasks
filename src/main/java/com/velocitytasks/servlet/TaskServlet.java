package com.velocitytasks.servlet;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.velocitytasks.model.Task;
import com.velocitytasks.model.TaskPriority;
import com.velocitytasks.service.TaskService;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Main servlet for handling task operations in VelocityTasks application.
 * Provides RESTful API endpoints for task management.
 */
public class TaskServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(TaskServlet.class.getName());
    private static final String CONTENT_TYPE_JSON = "application/json";
    private static final String CHARACTER_ENCODING = "UTF-8";
    
    private TaskService taskService;
    private Gson gson;

    @Override
    public void init() throws ServletException {
        super.init();
        this.taskService = TaskService.getInstance();
        this.gson = new GsonBuilder()
                .setPrettyPrinting()
                .create();
        LOGGER.info("TaskServlet initialized successfully");
    }

    /**
     * GET /api/tasks - Get all tasks
     * GET /api/tasks/{id} - Get specific task
     */
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        setupCORSHeaders(response);
        response.setContentType(CONTENT_TYPE_JSON);
        response.setCharacterEncoding(CHARACTER_ENCODING);

        try {
            String pathInfo = request.getPathInfo();
            
            if (pathInfo == null || pathInfo.equals("/")) {
                // Get all tasks with optional filtering
                handleGetAllTasks(request, response);
            } else {
                // Get specific task by ID
                String taskId = pathInfo.substring(1); // Remove leading slash
                handleGetTaskById(taskId, response);
            }
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error handling GET request", e);
            sendErrorResponse(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, 
                            "Internal server error");
        }
    }

    /**
     * POST /api/tasks - Create new task
     */
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        setupCORSHeaders(response);
        response.setContentType(CONTENT_TYPE_JSON);
        response.setCharacterEncoding(CHARACTER_ENCODING);

        try {
            Task task = gson.fromJson(request.getReader(), Task.class);
            
            if (task == null || task.getTitle() == null || task.getTitle().trim().isEmpty()) {
                sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                                "Task title is required");
                return;
            }

            // Ensure priority is set
            if (task.getPriority() == null) {
                task.setPriority(TaskPriority.MEDIUM);
            }

            Task createdTask = taskService.addTask(task);
            
            response.setStatus(HttpServletResponse.SC_CREATED);
            try (PrintWriter writer = response.getWriter()) {
                writer.write(gson.toJson(createdTask));
            }
            
            LOGGER.info("Created new task: " + createdTask.getId());
            
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error creating task", e);
            sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                            "Invalid task data");
        }
    }

    /**
     * PUT /api/tasks/{id} - Update existing task
     */
    @Override
    protected void doPut(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        setupCORSHeaders(response);
        response.setContentType(CONTENT_TYPE_JSON);
        response.setCharacterEncoding(CHARACTER_ENCODING);

        try {
            String pathInfo = request.getPathInfo();
            if (pathInfo == null || pathInfo.equals("/")) {
                sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                                "Task ID is required");
                return;
            }

            String taskId = pathInfo.substring(1); // Remove leading slash
            Task updatedTask = gson.fromJson(request.getReader(), Task.class);
            
            if (updatedTask == null) {
                sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                                "Invalid task data");
                return;
            }

            Optional<Task> result = taskService.updateTask(taskId, updatedTask);
            
            if (result.isPresent()) {
                try (PrintWriter writer = response.getWriter()) {
                    writer.write(gson.toJson(result.get()));
                }
                LOGGER.info("Updated task: " + taskId);
            } else {
                sendErrorResponse(response, HttpServletResponse.SC_NOT_FOUND, 
                                "Task not found");
            }
            
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error updating task", e);
            sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                            "Invalid task data");
        }
    }

    /**
     * DELETE /api/tasks/{id} - Delete task
     */
    @Override
    protected void doDelete(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        setupCORSHeaders(response);
        response.setContentType(CONTENT_TYPE_JSON);
        response.setCharacterEncoding(CHARACTER_ENCODING);

        try {
            String pathInfo = request.getPathInfo();
            if (pathInfo == null || pathInfo.equals("/")) {
                sendErrorResponse(response, HttpServletResponse.SC_BAD_REQUEST, 
                                "Task ID is required");
                return;
            }

            String taskId = pathInfo.substring(1); // Remove leading slash
            boolean deleted = taskService.deleteTask(taskId);
            
            if (deleted) {
                response.setStatus(HttpServletResponse.SC_NO_CONTENT);
                LOGGER.info("Deleted task: " + taskId);
            } else {
                sendErrorResponse(response, HttpServletResponse.SC_NOT_FOUND, 
                                "Task not found");
            }
            
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error deleting task", e);
            sendErrorResponse(response, HttpServletResponse.SC_INTERNAL_SERVER_ERROR, 
                            "Internal server error");
        }
    }

    /**
     * Handle OPTIONS requests for CORS preflight
     */
    @Override
    protected void doOptions(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        setupCORSHeaders(response);
        response.setStatus(HttpServletResponse.SC_OK);
    }

    private void handleGetAllTasks(HttpServletRequest request, HttpServletResponse response) 
            throws IOException {
        
        String status = request.getParameter("status");
        String priority = request.getParameter("priority");
        String search = request.getParameter("search");
        
        List<Task> tasks;
        
        if (search != null && !search.trim().isEmpty()) {
            tasks = taskService.searchTasks(search);
        } else if ("completed".equals(status)) {
            tasks = taskService.getTasksByStatus(true);
        } else if ("pending".equals(status)) {
            tasks = taskService.getTasksByStatus(false);
        } else if (priority != null) {
            TaskPriority taskPriority = TaskPriority.fromString(priority);
            tasks = taskService.getTasksByPriority(taskPriority);
        } else {
            tasks = taskService.getAllTasks();
        }
        
        try (PrintWriter writer = response.getWriter()) {
            writer.write(gson.toJson(tasks));
        }
    }

    private void handleGetTaskById(String taskId, HttpServletResponse response) 
            throws IOException {
        
        Optional<Task> task = taskService.getTaskById(taskId);
        
        if (task.isPresent()) {
            try (PrintWriter writer = response.getWriter()) {
                writer.write(gson.toJson(task.get()));
            }
        } else {
            sendErrorResponse(response, HttpServletResponse.SC_NOT_FOUND, 
                            "Task not found");
        }
    }

    private void setupCORSHeaders(HttpServletResponse response) {
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
        response.setHeader("Access-Control-Max-Age", "3600");
    }

    private void sendErrorResponse(HttpServletResponse response, int statusCode, String message) 
            throws IOException {
        
        response.setStatus(statusCode);
        try (PrintWriter writer = response.getWriter()) {
            writer.write(gson.toJson(new ErrorResponse(message, statusCode)));
        }
    }

    /**
     * Simple error response class
     */
    private static class ErrorResponse {
        private final String error;
        private final int status;
        private final long timestamp;

        public ErrorResponse(String error, int status) {
            this.error = error;
            this.status = status;
            this.timestamp = System.currentTimeMillis();
        }

        public String getError() { return error; }
        public int getStatus() { return status; }
        public long getTimestamp() { return timestamp; }
    }
}
