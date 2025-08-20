package com.velocitytasks.servlet;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.velocitytasks.service.TaskService;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Servlet for providing task statistics and application metrics.
 */
public class StatsServlet extends HttpServlet {
    private static final Logger LOGGER = Logger.getLogger(StatsServlet.class.getName());
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
        LOGGER.info("StatsServlet initialized successfully");
    }

    /**
     * GET /api/stats - Get application statistics
     */
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        setupCORSHeaders(response);
        response.setContentType(CONTENT_TYPE_JSON);
        response.setCharacterEncoding(CHARACTER_ENCODING);

        try {
            TaskService.TaskStats taskStats = taskService.getTaskStats();
            AppStats appStats = new AppStats(taskStats);
            
            try (PrintWriter writer = response.getWriter()) {
                writer.write(gson.toJson(appStats));
            }
            
        } catch (Exception e) {
            LOGGER.log(Level.SEVERE, "Error getting statistics", e);
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            try (PrintWriter writer = response.getWriter()) {
                writer.write(gson.toJson(new ErrorResponse("Internal server error", 500)));
            }
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

    private void setupCORSHeaders(HttpServletResponse response) {
        response.setHeader("Access-Control-Allow-Origin", "*");
        response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
        response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
        response.setHeader("Access-Control-Max-Age", "3600");
    }

    /**
     * Application statistics response
     */
    private static class AppStats {
        private final TaskCounts tasks;
        private final PriorityCounts priority;
        private final long timestamp;
        private final String version;

        public AppStats(TaskService.TaskStats taskStats) {
            this.tasks = new TaskCounts(taskStats);
            this.priority = new PriorityCounts(taskStats);
            this.timestamp = System.currentTimeMillis();
            this.version = "1.0.0";
        }

        public TaskCounts getTasks() { return tasks; }
        public PriorityCounts getPriority() { return priority; }
        public long getTimestamp() { return timestamp; }
        public String getVersion() { return version; }
    }

    /**
     * Task count statistics
     */
    private static class TaskCounts {
        private final long total;
        private final long completed;
        private final long pending;
        private final double completionRate;

        public TaskCounts(TaskService.TaskStats taskStats) {
            this.total = taskStats.getTotal();
            this.completed = taskStats.getCompleted();
            this.pending = taskStats.getPending();
            this.completionRate = total > 0 ? (double) completed / total * 100 : 0;
        }

        public long getTotal() { return total; }
        public long getCompleted() { return completed; }
        public long getPending() { return pending; }
        public double getCompletionRate() { return Math.round(completionRate * 100.0) / 100.0; }
    }

    /**
     * Priority distribution statistics
     */
    private static class PriorityCounts {
        private final long high;
        private final long medium;
        private final long low;

        public PriorityCounts(TaskService.TaskStats taskStats) {
            this.high = taskStats.getHighPriority();
            this.medium = taskStats.getMediumPriority();
            this.low = taskStats.getLowPriority();
        }

        public long getHigh() { return high; }
        public long getMedium() { return medium; }
        public long getLow() { return low; }
    }

    /**
     * Error response class
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
