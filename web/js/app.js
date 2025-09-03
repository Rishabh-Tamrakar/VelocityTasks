/**
 * VelocityTasks Main Application
 * Orchestrates the entire application state and interactions
 */

class VelocityApp {
    constructor() {
        this.tasks = [];
        this.stats = {
            total: 0,
            completed: 0,
            pending: 0,
            in_progress: 0,
            high_priority: 0,
            medium_priority: 0,
            low_priority: 0
        };
        this.isOnline = navigator.onLine;
        this.retryQueue = [];
        this.autoSaveTimer = null;
        
        this.init();
    }

    /**
     * Initialize the application
     */
    async init() {
        try {
            // Show loading spinner
            window.velocityUI.showLoading();
            
            // Setup offline/online handlers
            this.setupNetworkHandlers();
            
            // Check API connectivity
            const isAPIReachable = await window.velocityAPI.isAPIReachable();
            if (!isAPIReachable) {
                window.velocityUI.showToast('Warning: API is not reachable. Some features may not work.', 'warning', 10000);
            }
            
            // Load initial data
            await this.loadTasks();
            await this.loadStats();
            
            // Render initial state
            this.render();
            
            // Setup auto-refresh
            this.setupAutoRefresh();
            
            // Hide loading spinner
            window.velocityUI.hideLoading();
            
            console.log('✅ VelocityTasks initialized successfully');
            
        } catch (error) {
            console.error('❌ Failed to initialize VelocityTasks:', error);
            window.velocityUI.hideLoading();
            window.velocityUI.showToast(
                'Failed to initialize application. Please refresh the page.',
                'error',
                0 // Don't auto-hide
            );
        }
    }

    /**
     * Setup network status handlers
     */
    setupNetworkHandlers() {
        window.addEventListener('online', () => {
            this.isOnline = true;
            window.velocityUI.showToast('Connection restored', 'success');
            this.processRetryQueue();
        });

        window.addEventListener('offline', () => {
            this.isOnline = false;
            window.velocityUI.showToast('You are offline. Changes will be saved when connection is restored.', 'warning', 10000);
        });
    }

    /**
     * Setup auto-refresh for real-time updates
     */
    setupAutoRefresh() {
        // Refresh every 30 seconds if online
        setInterval(async () => {
            if (this.isOnline && document.visibilityState === 'visible') {
                try {
                    await this.refreshData();
                } catch (error) {
                    // Silently fail for auto-refresh
                    console.warn('Auto-refresh failed:', error.message);
                }
            }
        }, 30000);

        // Refresh when page becomes visible
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible' && this.isOnline) {
                this.refreshData();
            }
        });
    }

    /**
     * Load all tasks from the API
     */
    async loadTasks() {
        try {
            const response = await window.velocityAPI.getTasks();
            this.tasks = response.tasks || [];
            console.log(`📋 Loaded ${this.tasks.length} tasks`);
        } catch (error) {
            console.error('Failed to load tasks:', error);
            
            if (!this.isOnline) {
                // Try to load from localStorage as fallback
                this.loadTasksFromStorage();
            } else {
                throw error;
            }
        }
    }

    /**
     * Load task statistics from the API
     */
    async loadStats() {
        try {
            const response = await window.velocityAPI.getStats();
            this.stats = response.stats || this.calculateLocalStats();
            console.log('📊 Loaded task statistics');
        } catch (error) {
            console.error('Failed to load stats:', error);
            // Calculate stats locally as fallback
            this.stats = this.calculateLocalStats();
        }
    }

    /**
     * Calculate statistics from local tasks data
     */
    calculateLocalStats() {
        const stats = {
            total: this.tasks.length,
            completed: 0,
            pending: 0,
            in_progress: 0,
            high_priority: 0,
            medium_priority: 0,
            low_priority: 0
        };

        this.tasks.forEach(task => {
            // Count by status
            if (task.status === 'completed') {
                stats.completed++;
            } else if (task.status === 'in_progress') {
                stats.in_progress++;
            } else {
                stats.pending++;
            }

            // Count by priority
            if (task.priority === 'high') {
                stats.high_priority++;
            } else if (task.priority === 'medium') {
                stats.medium_priority++;
            } else {
                stats.low_priority++;
            }
        });

        return stats;
    }

    /**
     * Refresh data from the API
     */
    async refreshData() {
        try {
            await Promise.all([
                this.loadTasks(),
                this.loadStats()
            ]);
            
            this.render();
        } catch (error) {
            console.warn('Failed to refresh data:', error.message);
        }
    }

    /**
     * Render the current application state
     */
    render() {
        window.velocityUI.renderTasks(this.tasks);
        window.velocityUI.updateStats(this.stats);
    }

    /**
     * Apply current filters and re-render
     */
    applyFilters() {
        window.velocityUI.renderTasks(this.tasks);
    }

    /**
     * Create a new task
     * @param {Object} taskData - Task data
     */
    async createTask(taskData) {
        try {
            if (!this.isOnline) {
                throw new Error('Cannot create tasks while offline');
            }

            const newTask = await window.velocityAPI.createTask(taskData);
            
            // Add to local array
            this.tasks.unshift(newTask);
            
            // Update stats
            this.stats.total++;
            this.stats.pending++;
            this.stats[`${newTask.priority}_priority`]++;
            
            // Re-render
            this.render();
            
            // Save to localStorage as backup
            this.saveTasksToStorage();
            
            console.log('✅ Task created:', newTask.id);
            
        } catch (error) {
            console.error('Failed to create task:', error);
            
            if (!this.isOnline) {
                // Queue for retry when online
                this.retryQueue.push({
                    action: 'create',
                    data: taskData,
                    timestamp: Date.now()
                });
                this.saveRetryQueue();
            }
            
            throw error;
        }
    }

    /**
     * Update an existing task
     * @param {string} taskId - Task ID
     * @param {Object} updates - Updates to apply
     */
    async updateTask(taskId, updates) {
        try {
            if (!this.isOnline) {
                throw new Error('Cannot update tasks while offline');
            }

            const updatedTask = await window.velocityAPI.updateTask(taskId, updates);
            
            // Update local array
            const index = this.tasks.findIndex(task => task.id === taskId);
            if (index !== -1) {
                const oldTask = this.tasks[index];
                this.tasks[index] = updatedTask;
                
                // Update stats if status or priority changed
                this.updateStatsForTaskChange(oldTask, updatedTask);
            }
            
            // Re-render
            this.render();
            
            // Save to localStorage as backup
            this.saveTasksToStorage();
            
            console.log('✅ Task updated:', taskId);
            
        } catch (error) {
            console.error('Failed to update task:', error);
            
            if (!this.isOnline) {
                // Queue for retry when online
                this.retryQueue.push({
                    action: 'update',
                    id: taskId,
                    data: updates,
                    timestamp: Date.now()
                });
                this.saveRetryQueue();
            }
            
            throw error;
        }
    }

    /**
     * Delete a task
     * @param {string} taskId - Task ID
     */
    async deleteTask(taskId) {
        try {
            if (!this.isOnline) {
                throw new Error('Cannot delete tasks while offline');
            }

            await window.velocityAPI.deleteTask(taskId);
            
            // Remove from local array
            const index = this.tasks.findIndex(task => task.id === taskId);
            if (index !== -1) {
                const deletedTask = this.tasks[index];
                this.tasks.splice(index, 1);
                
                // Update stats
                this.stats.total--;
                this.stats[deletedTask.status]--;
                this.stats[`${deletedTask.priority}_priority`]--;
            }
            
            // Re-render
            this.render();
            
            // Save to localStorage as backup
            this.saveTasksToStorage();
            
            console.log('✅ Task deleted:', taskId);
            
        } catch (error) {
            console.error('Failed to delete task:', error);
            
            if (!this.isOnline) {
                // Queue for retry when online
                this.retryQueue.push({
                    action: 'delete',
                    id: taskId,
                    timestamp: Date.now()
                });
                this.saveRetryQueue();
            }
            
            throw error;
        }
    }

    /**
     * Search tasks
     * @param {Object} searchParams - Search parameters
     */
    async searchTasks(searchParams) {
        try {
            const response = await window.velocityAPI.searchTasks(searchParams);
            return response.tasks || [];
        } catch (error) {
            console.error('Failed to search tasks:', error);
            
            // Fallback to local filtering
            return this.filterTasksLocally(searchParams);
        }
    }

    /**
     * Filter tasks locally
     * @param {Object} searchParams - Search parameters
     */
    filterTasksLocally(searchParams) {
        let filtered = [...this.tasks];

        if (searchParams.q) {
            const query = searchParams.q.toLowerCase();
            filtered = filtered.filter(task => 
                task.title.toLowerCase().includes(query) ||
                task.description.toLowerCase().includes(query)
            );
        }

        if (searchParams.priority) {
            filtered = filtered.filter(task => task.priority === searchParams.priority);
        }

        if (searchParams.status) {
            filtered = filtered.filter(task => task.status === searchParams.status);
        }

        return filtered;
    }

    /**
     * Update stats when a task changes
     * @param {Object} oldTask - Original task
     * @param {Object} newTask - Updated task
     */
    updateStatsForTaskChange(oldTask, newTask) {
        // Update status counts
        if (oldTask.status !== newTask.status) {
            this.stats[oldTask.status]--;
            this.stats[newTask.status]++;
        }

        // Update priority counts
        if (oldTask.priority !== newTask.priority) {
            this.stats[`${oldTask.priority}_priority`]--;
            this.stats[`${newTask.priority}_priority`]++;
        }
    }

    /**
     * Process retry queue when coming back online
     */
    async processRetryQueue() {
        if (this.retryQueue.length === 0) return;

        console.log(`🔄 Processing ${this.retryQueue.length} queued operations`);
        
        const queue = [...this.retryQueue];
        this.retryQueue = [];
        
        let successCount = 0;
        let failCount = 0;

        for (const operation of queue) {
            try {
                switch (operation.action) {
                    case 'create':
                        await this.createTask(operation.data);
                        break;
                    case 'update':
                        await this.updateTask(operation.id, operation.data);
                        break;
                    case 'delete':
                        await this.deleteTask(operation.id);
                        break;
                }
                successCount++;
            } catch (error) {
                console.error('Failed to process queued operation:', error);
                failCount++;
                // Re-queue failed operations
                this.retryQueue.push(operation);
            }
        }

        if (successCount > 0) {
            window.velocityUI.showToast(`Successfully synchronized ${successCount} operations`, 'success');
        }

        if (failCount > 0) {
            window.velocityUI.showToast(`Failed to synchronize ${failCount} operations`, 'error');
        }

        this.saveRetryQueue();
    }

    /**
     * Save tasks to localStorage
     */
    saveTasksToStorage() {
        try {
            localStorage.setItem('velocityTasks', JSON.stringify({
                tasks: this.tasks,
                stats: this.stats,
                lastUpdated: Date.now()
            }));
        } catch (error) {
            console.warn('Failed to save tasks to localStorage:', error);
        }
    }

    /**
     * Load tasks from localStorage
     */
    loadTasksFromStorage() {
        try {
            const data = localStorage.getItem('velocityTasks');
            if (data) {
                const parsed = JSON.parse(data);
                this.tasks = parsed.tasks || [];
                this.stats = parsed.stats || this.calculateLocalStats();
                
                window.velocityUI.showToast('Loaded cached data', 'info');
                console.log('📦 Loaded tasks from localStorage');
            }
        } catch (error) {
            console.warn('Failed to load tasks from localStorage:', error);
        }
    }

    /**
     * Save retry queue to localStorage
     */
    saveRetryQueue() {
        try {
            localStorage.setItem('velocityRetryQueue', JSON.stringify(this.retryQueue));
        } catch (error) {
            console.warn('Failed to save retry queue:', error);
        }
    }

    /**
     * Load retry queue from localStorage
     */
    loadRetryQueue() {
        try {
            const data = localStorage.getItem('velocityRetryQueue');
            if (data) {
                this.retryQueue = JSON.parse(data);
                
                // Remove old operations (older than 24 hours)
                const dayAgo = Date.now() - (24 * 60 * 60 * 1000);
                this.retryQueue = this.retryQueue.filter(op => op.timestamp > dayAgo);
            }
        } catch (error) {
            console.warn('Failed to load retry queue:', error);
            this.retryQueue = [];
        }
    }

    /**
     * Get current application state
     */
    getState() {
        return {
            tasks: this.tasks,
            stats: this.stats,
            isOnline: this.isOnline,
            retryQueueLength: this.retryQueue.length
        };
    }

    /**
     * Clear all data (for development/testing)
     */
    async clearAllData() {
        try {
            // Clear local data
            this.tasks = [];
            this.stats = this.calculateLocalStats();
            
            // Clear localStorage
            localStorage.removeItem('velocityTasks');
            localStorage.removeItem('velocityRetryQueue');
            
            // Re-render
            this.render();
            
            window.velocityUI.showToast('All data cleared', 'info');
            
        } catch (error) {
            console.error('Failed to clear data:', error);
            window.velocityUI.showToast('Failed to clear data', 'error');
        }
    }

    /**
     * Export tasks data
     */
    exportTasks() {
        try {
            const data = {
                tasks: this.tasks,
                stats: this.stats,
                exportedAt: new Date().toISOString(),
                version: '1.0.0'
            };

            const blob = new Blob([JSON.stringify(data, null, 2)], {
                type: 'application/json'
            });

            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `velocitytasks-export-${new Date().toISOString().split('T')[0]}.json`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);

            window.velocityUI.showToast('Tasks exported successfully', 'success');

        } catch (error) {
            console.error('Failed to export tasks:', error);
            window.velocityUI.showToast('Failed to export tasks', 'error');
        }
    }
}

// Initialize the application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.velocityApp = new VelocityApp();
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = VelocityApp;
}

// Global error handler
window.addEventListener('error', (event) => {
    console.error('Global error:', event.error);
    if (window.velocityUI) {
        window.velocityUI.showToast('An unexpected error occurred', 'error');
    }
});

// Unhandled promise rejection handler
window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', event.reason);
    if (window.velocityUI) {
        window.velocityUI.showToast('An unexpected error occurred', 'error');
    }
});

// Performance monitoring
if ('performance' in window) {
    window.addEventListener('load', () => {
        setTimeout(() => {
            const perfData = performance.getEntriesByType('navigation')[0];
            console.log(`📊 Page load time: ${Math.round(perfData.loadEventEnd - perfData.fetchStart)}ms`);
        }, 0);
    });
}
