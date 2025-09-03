/**
 * VelocityTasks UI Components and DOM Manipulation
 * Handles all user interface interactions and updates
 */

class VelocityUI {
    constructor() {
        this.elements = {};
        this.currentFilter = 'all';
        this.currentSearch = '';
        this.modalStack = [];
        this.toastQueue = [];
        this.animationDelay = 100; // Delay between card animations
        
        this.init();
    }

    /**
     * Initialize UI components and event listeners
     */
    init() {
        this.cacheElements();
        this.setupEventListeners();
        this.setupKeyboardNavigation();
        this.setupIntersectionObserver();
    }

    /**
     * Cache frequently used DOM elements
     */
    cacheElements() {
        this.elements = {
            // Main containers
            app: document.getElementById('app'),
            loadingSpinner: document.getElementById('loading-spinner'),
            tasksGrid: document.getElementById('tasks-grid'),
            emptyState: document.getElementById('empty-state'),
            
            // Forms
            taskForm: document.getElementById('task-form'),
            taskTitle: document.getElementById('task-title'),
            taskDescription: document.getElementById('task-description'),
            taskPriority: document.getElementById('task-priority'),
            
            // Search and filters
            searchInput: document.getElementById('search-input'),
            filterTabs: document.querySelectorAll('.filter-tab'),
            
            // Statistics
            totalTasks: document.getElementById('total-tasks'),
            completedTasks: document.getElementById('completed-tasks'),
            pendingTasks: document.getElementById('pending-tasks'),
            
            // Modal
            taskModal: document.getElementById('task-modal'),
            modalTitle: document.getElementById('modal-title'),
            modalClose: document.querySelector('.modal-close'),
            editForm: document.getElementById('edit-task-form'),
            editTaskId: document.getElementById('edit-task-id'),
            editTaskTitle: document.getElementById('edit-task-title'),
            editTaskDescription: document.getElementById('edit-task-description'),
            editTaskPriority: document.getElementById('edit-task-priority'),
            editTaskStatus: document.getElementById('edit-task-status'),
            cancelEdit: document.getElementById('cancel-edit'),
            
            // Confirm dialog
            confirmDialog: document.getElementById('confirm-dialog'),
            confirmTitle: document.getElementById('confirm-title'),
            confirmMessage: document.getElementById('confirm-message'),
            confirmOk: document.getElementById('confirm-ok'),
            confirmCancel: document.getElementById('confirm-cancel'),
            
            // Toast container
            toastContainer: document.getElementById('toast-container'),
        };
    }

    /**
     * Setup event listeners for all interactive elements
     */
    setupEventListeners() {
        // Task form submission
        this.elements.taskForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleTaskFormSubmit();
        });

        // Search input
        this.elements.searchInput.addEventListener('input', (e) => {
            this.handleSearchInput(e.target.value);
        });

        // Filter tabs
        this.elements.filterTabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                this.handleFilterChange(e.target.dataset.filter);
            });
        });

        // Modal events
        this.elements.modalClose.addEventListener('click', () => {
            this.closeModal();
        });

        this.elements.cancelEdit.addEventListener('click', () => {
            this.closeModal();
        });

        this.elements.editForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleEditFormSubmit();
        });

        // Modal overlay click to close
        this.elements.taskModal.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal-overlay')) {
                this.closeModal();
            }
        });

        // Confirm dialog events
        this.elements.confirmCancel.addEventListener('click', () => {
            this.closeConfirmDialog();
        });

        // ESC key to close modals
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (this.elements.taskModal.style.display !== 'none') {
                    this.closeModal();
                } else if (this.elements.confirmDialog.style.display !== 'none') {
                    this.closeConfirmDialog();
                }
            }
        });

        // Form input validation
        this.elements.taskTitle.addEventListener('input', () => {
            this.validateTaskTitle();
        });

        this.elements.editTaskTitle.addEventListener('input', () => {
            this.validateEditTaskTitle();
        });
    }

    /**
     * Setup keyboard navigation for accessibility
     */
    setupKeyboardNavigation() {
        // Tab navigation for filter tabs
        this.elements.filterTabs.forEach((tab, index) => {
            tab.addEventListener('keydown', (e) => {
                if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                    e.preventDefault();
                    const direction = e.key === 'ArrowRight' ? 1 : -1;
                    const nextIndex = (index + direction + this.elements.filterTabs.length) % this.elements.filterTabs.length;
                    this.elements.filterTabs[nextIndex].focus();
                }
            });
        });
    }

    /**
     * Setup intersection observer for scroll animations
     */
    setupIntersectionObserver() {
        if ('IntersectionObserver' in window) {
            this.observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('visible');
                    }
                });
            }, {
                threshold: 0.1,
                rootMargin: '50px'
            });
        }
    }

    /**
     * Show loading spinner
     */
    showLoading() {
        this.elements.loadingSpinner.style.display = 'flex';
        this.elements.app.style.display = 'none';
    }

    /**
     * Hide loading spinner and show app
     */
    hideLoading() {
        this.elements.loadingSpinner.style.display = 'none';
        this.elements.app.style.display = 'block';
    }

    /**
     * Render tasks in the grid
     * @param {Array} tasks - Array of task objects
     */
    renderTasks(tasks) {
        const filteredTasks = this.filterTasks(tasks);
        
        if (filteredTasks.length === 0) {
            this.showEmptyState();
            return;
        }

        this.hideEmptyState();
        this.elements.tasksGrid.innerHTML = '';

        filteredTasks.forEach((task, index) => {
            const taskCard = this.createTaskCard(task);
            taskCard.style.animationDelay = `${index * 0.1}s`;
            this.elements.tasksGrid.appendChild(taskCard);

            // Add to intersection observer
            if (this.observer) {
                this.observer.observe(taskCard);
            }
        });
    }

    /**
     * Create a task card element
     * @param {Object} task - Task object
     * @returns {HTMLElement} - Task card element
     */
    createTaskCard(task) {
        const card = document.createElement('div');
        card.className = `task-card ${task.status}`;
        card.setAttribute('data-task-id', task.id);
        card.setAttribute('role', 'article');
        card.setAttribute('aria-labelledby', `task-title-${task.id}`);

        const priorityColor = this.getPriorityColor(task.priority);
        const statusText = this.getStatusText(task.status);
        const createdDate = new Date(task.created_at).toLocaleDateString();
        const updatedDate = new Date(task.updated_at).toLocaleDateString();

        card.innerHTML = `
            <div class="task-header">
                <h3 class="task-title" id="task-title-${task.id}">${this.escapeHtml(task.title)}</h3>
                <span class="task-priority ${task.priority}" title="${task.priority} priority">
                    ${task.priority}
                </span>
            </div>
            
            ${task.description ? `
                <div class="task-description">
                    ${this.escapeHtml(task.description)}
                </div>
            ` : ''}
            
            <div class="task-footer">
                <div class="task-meta">
                    <div class="task-status ${task.status}" title="Status: ${statusText}">
                        ${statusText}
                    </div>
                    <div class="task-date" title="Created: ${createdDate}${updatedDate !== createdDate ? `, Updated: ${updatedDate}` : ''}">
                        ${createdDate}
                    </div>
                </div>
                
                <div class="task-actions">
                    ${task.status !== 'completed' ? `
                        <button class="task-btn complete" 
                                onclick="velocityUI.markTaskCompleted('${task.id}')"
                                title="Mark as completed"
                                aria-label="Mark task as completed">
                            ✓
                        </button>
                    ` : ''}
                    <button class="task-btn edit" 
                            onclick="velocityUI.editTask('${task.id}')"
                            title="Edit task"
                            aria-label="Edit task">
                        ✎
                    </button>
                    <button class="task-btn delete" 
                            onclick="velocityUI.deleteTask('${task.id}')"
                            title="Delete task"
                            aria-label="Delete task">
                        🗑
                    </button>
                </div>
            </div>
        `;

        // Add click handler for task details
        card.addEventListener('click', (e) => {
            if (!e.target.classList.contains('task-btn')) {
                this.showTaskDetails(task);
            }
        });

        return card;
    }

    /**
     * Filter tasks based on current filter and search
     * @param {Array} tasks - Array of task objects
     * @returns {Array} - Filtered tasks
     */
    filterTasks(tasks) {
        let filtered = tasks;

        // Apply status filter
        if (this.currentFilter !== 'all') {
            if (this.currentFilter === 'high') {
                filtered = filtered.filter(task => task.priority === 'high');
            } else {
                filtered = filtered.filter(task => task.status === this.currentFilter);
            }
        }

        // Apply search filter
        if (this.currentSearch.trim()) {
            const searchTerm = this.currentSearch.toLowerCase().trim();
            filtered = filtered.filter(task => 
                task.title.toLowerCase().includes(searchTerm) ||
                task.description.toLowerCase().includes(searchTerm)
            );
        }

        return filtered;
    }

    /**
     * Update statistics display
     * @param {Object} stats - Statistics object
     */
    updateStats(stats) {
        this.animateCounterUpdate(this.elements.totalTasks, stats.total);
        this.animateCounterUpdate(this.elements.completedTasks, stats.completed);
        this.animateCounterUpdate(this.elements.pendingTasks, stats.pending + stats.in_progress);
    }

    /**
     * Animate counter update
     * @param {HTMLElement} element - Counter element
     * @param {number} newValue - New counter value
     */
    animateCounterUpdate(element, newValue) {
        const currentValue = parseInt(element.textContent) || 0;
        const increment = newValue > currentValue ? 1 : -1;
        const steps = Math.abs(newValue - currentValue);
        
        if (steps === 0) return;

        element.classList.add('updating');
        
        let current = currentValue;
        const timer = setInterval(() => {
            current += increment;
            element.textContent = current;
            
            if (current === newValue) {
                clearInterval(timer);
                element.classList.remove('updating');
            }
        }, 50);
    }

    /**
     * Show empty state
     */
    showEmptyState() {
        this.elements.emptyState.style.display = 'block';
        this.elements.tasksGrid.style.display = 'none';
    }

    /**
     * Hide empty state
     */
    hideEmptyState() {
        this.elements.emptyState.style.display = 'none';
        this.elements.tasksGrid.style.display = 'grid';
    }

    /**
     * Handle task form submission
     */
    async handleTaskFormSubmit() {
        const title = this.elements.taskTitle.value.trim();
        const description = this.elements.taskDescription.value.trim();
        const priority = this.elements.taskPriority.value;

        if (!title) {
            this.showToast('Task title is required', 'error');
            this.elements.taskTitle.focus();
            return;
        }

        try {
            this.setFormLoading(true);
            
            const taskData = { title, description, priority };
            await window.velocityApp.createTask(taskData);
            
            // Clear form
            this.elements.taskForm.reset();
            this.showToast('Task created successfully!', 'success');
            
        } catch (error) {
            this.showToast(error.message, 'error');
        } finally {
            this.setFormLoading(false);
        }
    }

    /**
     * Handle search input
     * @param {string} searchTerm - Search term
     */
    handleSearchInput(searchTerm) {
        this.currentSearch = searchTerm;
        window.velocityApp.applyFilters();
    }

    /**
     * Handle filter change
     * @param {string} filter - Filter type
     */
    handleFilterChange(filter) {
        // Update active filter tab
        this.elements.filterTabs.forEach(tab => {
            const isActive = tab.dataset.filter === filter;
            tab.classList.toggle('active', isActive);
            tab.setAttribute('aria-pressed', isActive);
        });

        this.currentFilter = filter;
        window.velocityApp.applyFilters();
    }

    /**
     * Edit a task
     * @param {string} taskId - Task ID
     */
    async editTask(taskId) {
        try {
            const task = await window.velocityAPI.getTask(taskId);
            this.openEditModal(task);
        } catch (error) {
            this.showToast(error.message, 'error');
        }
    }

    /**
     * Open edit modal with task data
     * @param {Object} task - Task object
     */
    openEditModal(task) {
        this.elements.editTaskId.value = task.id;
        this.elements.editTaskTitle.value = task.title;
        this.elements.editTaskDescription.value = task.description;
        this.elements.editTaskPriority.value = task.priority;
        this.elements.editTaskStatus.value = task.status;

        this.openModal();
        this.elements.editTaskTitle.focus();
    }

    /**
     * Handle edit form submission
     */
    async handleEditFormSubmit() {
        const taskId = this.elements.editTaskId.value;
        const updates = {
            title: this.elements.editTaskTitle.value.trim(),
            description: this.elements.editTaskDescription.value.trim(),
            priority: this.elements.editTaskPriority.value,
            status: this.elements.editTaskStatus.value,
        };

        if (!updates.title) {
            this.showToast('Task title is required', 'error');
            this.elements.editTaskTitle.focus();
            return;
        }

        try {
            this.setModalLoading(true);
            
            await window.velocityApp.updateTask(taskId, updates);
            this.closeModal();
            this.showToast('Task updated successfully!', 'success');
            
        } catch (error) {
            this.showToast(error.message, 'error');
        } finally {
            this.setModalLoading(false);
        }
    }

    /**
     * Mark task as completed
     * @param {string} taskId - Task ID
     */
    async markTaskCompleted(taskId) {
        try {
            await window.velocityApp.updateTask(taskId, { status: 'completed' });
            this.showToast('Task marked as completed!', 'success');
        } catch (error) {
            this.showToast(error.message, 'error');
        }
    }

    /**
     * Delete a task with confirmation
     * @param {string} taskId - Task ID
     */
    deleteTask(taskId) {
        this.showConfirmDialog(
            'Delete Task',
            'Are you sure you want to delete this task? This action cannot be undone.',
            async () => {
                try {
                    await window.velocityApp.deleteTask(taskId);
                    this.showToast('Task deleted successfully!', 'success');
                } catch (error) {
                    this.showToast(error.message, 'error');
                }
            }
        );
    }

    /**
     * Show task details (for future implementation)
     * @param {Object} task - Task object
     */
    showTaskDetails(task) {
        // Future: Show detailed task view
        console.log('Show task details:', task);
    }

    /**
     * Open modal
     */
    openModal() {
        this.elements.taskModal.style.display = 'flex';
        this.elements.taskModal.classList.add('show');
        this.elements.taskModal.setAttribute('aria-hidden', 'false');
        document.body.style.overflow = 'hidden';
        
        this.modalStack.push('task-modal');
    }

    /**
     * Close modal
     */
    closeModal() {
        this.elements.taskModal.classList.remove('show');
        this.elements.taskModal.setAttribute('aria-hidden', 'true');
        
        setTimeout(() => {
            this.elements.taskModal.style.display = 'none';
            document.body.style.overflow = '';
        }, 300);
        
        this.modalStack.pop();
    }

    /**
     * Show confirmation dialog
     * @param {string} title - Dialog title
     * @param {string} message - Dialog message
     * @param {Function} onConfirm - Confirmation callback
     */
    showConfirmDialog(title, message, onConfirm) {
        this.elements.confirmTitle.textContent = title;
        this.elements.confirmMessage.textContent = message;
        
        this.elements.confirmDialog.style.display = 'flex';
        this.elements.confirmDialog.classList.add('show');
        this.elements.confirmDialog.setAttribute('aria-hidden', 'false');
        
        // Remove existing event listeners
        const newConfirmOk = this.elements.confirmOk.cloneNode(true);
        this.elements.confirmOk.parentNode.replaceChild(newConfirmOk, this.elements.confirmOk);
        this.elements.confirmOk = newConfirmOk;
        
        this.elements.confirmOk.addEventListener('click', async () => {
            this.closeConfirmDialog();
            if (onConfirm) {
                await onConfirm();
            }
        });
        
        this.elements.confirmOk.focus();
    }

    /**
     * Close confirmation dialog
     */
    closeConfirmDialog() {
        this.elements.confirmDialog.classList.remove('show');
        this.elements.confirmDialog.setAttribute('aria-hidden', 'true');
        
        setTimeout(() => {
            this.elements.confirmDialog.style.display = 'none';
        }, 300);
    }

    /**
     * Show toast notification
     * @param {string} message - Toast message
     * @param {string} type - Toast type (success, error, info, warning)
     * @param {number} duration - Duration in milliseconds
     */
    showToast(message, type = 'info', duration = 5000) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.setAttribute('role', 'alert');
        toast.setAttribute('aria-live', 'polite');
        
        const icon = this.getToastIcon(type);
        toast.innerHTML = `
            <div class="toast-content">
                <span class="toast-icon">${icon}</span>
                <span class="toast-message">${this.escapeHtml(message)}</span>
                <button class="toast-close" aria-label="Close notification">&times;</button>
            </div>
        `;

        const closeBtn = toast.querySelector('.toast-close');
        closeBtn.addEventListener('click', () => {
            this.removeToast(toast);
        });

        this.elements.toastContainer.appendChild(toast);
        
        // Trigger animation
        setTimeout(() => {
            toast.classList.add('show');
        }, 10);

        // Auto remove
        if (duration > 0) {
            setTimeout(() => {
                this.removeToast(toast);
            }, duration);
        }
    }

    /**
     * Remove toast notification
     * @param {HTMLElement} toast - Toast element
     */
    removeToast(toast) {
        toast.classList.add('hide');
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    }

    /**
     * Get toast icon for type
     * @param {string} type - Toast type
     * @returns {string} - Icon
     */
    getToastIcon(type) {
        const icons = {
            success: '✓',
            error: '✗',
            warning: '⚠',
            info: 'ℹ'
        };
        return icons[type] || icons.info;
    }

    /**
     * Set form loading state
     * @param {boolean} loading - Loading state
     */
    setFormLoading(loading) {
        const submitBtn = this.elements.taskForm.querySelector('button[type="submit"]');
        const inputs = this.elements.taskForm.querySelectorAll('input, textarea, select');
        
        if (loading) {
            submitBtn.disabled = true;
            submitBtn.classList.add('loading');
            submitBtn.querySelector('.btn-text').textContent = 'Adding...';
            inputs.forEach(input => input.disabled = true);
        } else {
            submitBtn.disabled = false;
            submitBtn.classList.remove('loading');
            submitBtn.querySelector('.btn-text').textContent = 'Add Task';
            inputs.forEach(input => input.disabled = false);
        }
    }

    /**
     * Set modal loading state
     * @param {boolean} loading - Loading state
     */
    setModalLoading(loading) {
        const submitBtn = this.elements.editForm.querySelector('button[type="submit"]');
        const inputs = this.elements.editForm.querySelectorAll('input, textarea, select');
        
        if (loading) {
            submitBtn.disabled = true;
            submitBtn.classList.add('loading');
            submitBtn.textContent = 'Saving...';
            inputs.forEach(input => input.disabled = true);
        } else {
            submitBtn.disabled = false;
            submitBtn.classList.remove('loading');
            submitBtn.textContent = 'Save Changes';
            inputs.forEach(input => input.disabled = false);
        }
    }

    /**
     * Validate task title input
     */
    validateTaskTitle() {
        const title = this.elements.taskTitle.value.trim();
        const maxLength = 200;
        
        if (title.length > maxLength) {
            this.elements.taskTitle.setCustomValidity(`Title must be less than ${maxLength} characters`);
        } else {
            this.elements.taskTitle.setCustomValidity('');
        }
    }

    /**
     * Validate edit task title input
     */
    validateEditTaskTitle() {
        const title = this.elements.editTaskTitle.value.trim();
        const maxLength = 200;
        
        if (title.length > maxLength) {
            this.elements.editTaskTitle.setCustomValidity(`Title must be less than ${maxLength} characters`);
        } else {
            this.elements.editTaskTitle.setCustomValidity('');
        }
    }

    /**
     * Get priority color class
     * @param {string} priority - Priority level
     * @returns {string} - Color class
     */
    getPriorityColor(priority) {
        const colors = {
            low: 'success',
            medium: 'warning',
            high: 'danger'
        };
        return colors[priority] || 'secondary';
    }

    /**
     * Get human-readable status text
     * @param {string} status - Status value
     * @returns {string} - Human-readable status
     */
    getStatusText(status) {
        const statusTexts = {
            pending: 'Pending',
            in_progress: 'In Progress',
            completed: 'Completed'
        };
        return statusTexts[status] || status;
    }

    /**
     * Escape HTML to prevent XSS
     * @param {string} text - Text to escape
     * @returns {string} - Escaped text
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Get current filter settings
     * @returns {Object} - Filter settings
     */
    getCurrentFilters() {
        return {
            filter: this.currentFilter,
            search: this.currentSearch
        };
    }

    /**
     * Reset all filters
     */
    resetFilters() {
        this.currentFilter = 'all';
        this.currentSearch = '';
        this.elements.searchInput.value = '';
        
        this.elements.filterTabs.forEach(tab => {
            const isActive = tab.dataset.filter === 'all';
            tab.classList.toggle('active', isActive);
            tab.setAttribute('aria-pressed', isActive);
        });
    }
}

// Create and export UI instance
window.velocityUI = new VelocityUI();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = VelocityUI;
}
