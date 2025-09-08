/**
 * VelocityTasks API Client
 * Handles all HTTP communication with the backend
 */

class VelocityAPI {
    constructor(baseURL = '') {
        this.baseURL = baseURL;
        this.timeout = 10000; // 10 seconds
    }

    /**
     * Make an HTTP request with error handling and timeout
     * @param {string} endpoint - The API endpoint
     * @param {Object} options - Fetch options
     * @returns {Promise<Object>} - The response data
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers,
            },
            ...options,
        };

        // Create abort controller for timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);
        
        try {
            const response = await fetch(url, {
                ...defaultOptions,
                signal: controller.signal,
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            clearTimeout(timeoutId);
            
            if (error.name === 'AbortError') {
                throw new Error('Request timeout - please try again');
            }
            
            if (!navigator.onLine) {
                throw new Error('No internet connection - please check your network');
            }
            
            throw error;
        }
    }

    /**
     * GET request helper
     * @param {string} endpoint - The API endpoint
     * @param {Object} params - Query parameters
     * @returns {Promise<Object>} - The response data
     */
    async get(endpoint, params = {}) {
        const url = new URL(endpoint, window.location.origin);
        Object.keys(params).forEach(key => {
            if (params[key] !== null && params[key] !== undefined && params[key] !== '') {
                url.searchParams.append(key, params[key]);
            }
        });
        
        return this.request(url.pathname + url.search);
    }

    /**
     * POST request helper
     * @param {string} endpoint - The API endpoint
     * @param {Object} data - Request body data
     * @returns {Promise<Object>} - The response data
     */
    async post(endpoint, data = {}) {
        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify(data),
        });
    }

    /**
     * PUT request helper
     * @param {string} endpoint - The API endpoint
     * @param {Object} data - Request body data
     * @returns {Promise<Object>} - The response data
     */
    async put(endpoint, data = {}) {
        return this.request(endpoint, {
            method: 'PUT',
            body: JSON.stringify(data),
        });
    }

    /**
     * DELETE request helper
     * @param {string} endpoint - The API endpoint
     * @returns {Promise<Object>} - The response data
     */
    async delete(endpoint) {
        return this.request(endpoint, {
            method: 'DELETE',
        });
    }

    // Task Management API Methods

    /**
     * Get all tasks
     * @returns {Promise<Object>} - Tasks data
     */
    async getTasks() {
        return this.get('/api/tasks');
    }

    /**
     * Get a specific task by ID
     * @param {string} id - Task ID
     * @returns {Promise<Object>} - Task data
     */
    async getTask(id) {
        return this.get(`/api/tasks/${id}`);
    }

    /**
     * Create a new task
     * @param {Object} taskData - Task data
     * @param {string} taskData.title - Task title
     * @param {string} taskData.description - Task description
     * @param {string} taskData.priority - Task priority (low, medium, high)
     * @returns {Promise<Object>} - Created task data
     */
    async createTask(taskData) {
        const { title, description, priority } = taskData;
        
        if (!title || title.trim().length === 0) {
            throw new Error('Task title is required');
        }
        
        if (title.length > 200) {
            throw new Error('Task title must be less than 200 characters');
        }
        
        if (description && description.length > 1000) {
            throw new Error('Task description must be less than 1000 characters');
        }
        
        const validPriorities = ['low', 'medium', 'high'];
        if (!validPriorities.includes(priority)) {
            throw new Error('Invalid priority. Must be low, medium, or high');
        }

        return this.post('/api/tasks', {
            title: title.trim(),
            description: description ? description.trim() : '',
            priority,
        });
    }

    /**
     * Update an existing task
     * @param {string} id - Task ID
     * @param {Object} updates - Task updates
     * @returns {Promise<Object>} - Updated task data
     */
    async updateTask(id, updates) {
        if (!id) {
            throw new Error('Task ID is required');
        }

        // Validate updates
        if (updates.title !== undefined) {
            if (!updates.title || updates.title.trim().length === 0) {
                throw new Error('Task title cannot be empty');
            }
            if (updates.title.length > 200) {
                throw new Error('Task title must be less than 200 characters');
            }
            updates.title = updates.title.trim();
        }

        if (updates.description !== undefined && updates.description.length > 1000) {
            throw new Error('Task description must be less than 1000 characters');
        }

        if (updates.priority !== undefined) {
            const validPriorities = ['low', 'medium', 'high'];
            if (!validPriorities.includes(updates.priority)) {
                throw new Error('Invalid priority. Must be low, medium, or high');
            }
        }

        if (updates.status !== undefined) {
            const validStatuses = ['pending', 'in_progress', 'completed'];
            if (!validStatuses.includes(updates.status)) {
                throw new Error('Invalid status. Must be pending, in_progress, or completed');
            }
        }

        return this.put(`/api/tasks/${id}`, updates);
    }

    /**
     * Delete a task
     * @param {string} id - Task ID
     * @returns {Promise<Object>} - Deletion confirmation
     */
    async deleteTask(id) {
        if (!id) {
            throw new Error('Task ID is required');
        }
        
        return this.delete(`/api/tasks/${id}`);
    }

    /**
     * Search tasks
     * @param {Object} params - Search parameters
     * @param {string} params.q - Search query
     * @param {string} params.priority - Priority filter
     * @param {string} params.status - Status filter
     * @param {number} params.limit - Result limit
     * @param {number} params.offset - Result offset
     * @returns {Promise<Object>} - Search results
     */
    async searchTasks(params = {}) {
        const { q, priority, status, limit, offset } = params;
        
        const searchParams = {};
        if (q && q.trim()) searchParams.q = q.trim();
        if (priority) searchParams.priority = priority;
        if (status) searchParams.status = status;
        if (limit && limit > 0) searchParams.limit = Math.min(limit, 1000); // Max 1000
        if (offset && offset >= 0) searchParams.offset = offset;

        return this.get('/api/tasks/search', searchParams);
    }

    /**
     * Get task statistics
     * @returns {Promise<Object>} - Task statistics
     */
    async getStats() {
        return this.get('/api/stats');
    }

    /**
     * Health check
     * @returns {Promise<Object>} - Health status
     */
    async healthCheck() {
        return this.get('/health');
    }

    // Batch Operations

    /**
     * Mark multiple tasks as completed
     * @param {string[]} taskIds - Array of task IDs
     * @returns {Promise<Object[]>} - Array of update results
     */
    async markTasksCompleted(taskIds) {
        if (!Array.isArray(taskIds) || taskIds.length === 0) {
            throw new Error('Task IDs array is required');
        }

        const promises = taskIds.map(id => 
            this.updateTask(id, { status: 'completed' })
        );

        return Promise.allSettled(promises);
    }

    /**
     * Delete multiple tasks
     * @param {string[]} taskIds - Array of task IDs
     * @returns {Promise<Object[]>} - Array of deletion results
     */
    async deleteTasks(taskIds) {
        if (!Array.isArray(taskIds) || taskIds.length === 0) {
            throw new Error('Task IDs array is required');
        }

        const promises = taskIds.map(id => this.deleteTask(id));
        return Promise.allSettled(promises);
    }

    // Utility Methods

    /**
     * Check if the API is reachable
     * @returns {Promise<boolean>} - API reachability status
     */
    async isAPIReachable() {
        try {
            await this.healthCheck();
            return true;
        } catch (error) {
            console.warn('API health check failed:', error.message);
            return false;
        }
    }

    /**
     * Get API information
     * @returns {Promise<Object>} - API information
     */
    async getAPIInfo() {
        try {
            const health = await this.healthCheck();
            return {
                available: true,
                ...health,
            };
        } catch (error) {
            return {
                available: false,
                error: error.message,
            };
        }
    }

    /**
     * Retry a failed request with exponential backoff
     * @param {Function} requestFn - Function that makes the request
     * @param {number} maxRetries - Maximum number of retries
     * @param {number} baseDelay - Base delay in milliseconds
     * @returns {Promise<Object>} - Request result
     */
    async retryRequest(requestFn, maxRetries = 3, baseDelay = 1000) {
        let lastError;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                return await requestFn();
            } catch (error) {
                lastError = error;
                
                if (attempt === maxRetries) {
                    break;
                }
                
                // Don't retry on client errors (4xx)
                if (error.message.includes('HTTP 4')) {
                    break;
                }
                
                // Exponential backoff
                const delay = baseDelay * Math.pow(2, attempt);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
        
        throw lastError;
    }
}

// Create and export API instance
window.velocityAPI = new VelocityAPI();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = VelocityAPI;
}
