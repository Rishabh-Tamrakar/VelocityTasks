package com.velocitytasks.service;

import com.velocitytasks.model.Task;
import com.velocitytasks.model.TaskPriority;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for TaskService
 */
class TaskServiceTest {
    
    private TaskService taskService;
    
    @BeforeEach
    void setUp() {
        // Note: In a real test environment, we'd want to use a separate instance
        // For this simple example, we'll use the singleton
        taskService = TaskService.getInstance();
    }
    
    @Test
    void testCreateTask() {
        Task task = new Task("Test Task", TaskPriority.HIGH);
        Task createdTask = taskService.addTask(task);
        
        assertNotNull(createdTask);
        assertNotNull(createdTask.getId());
        assertEquals("Test Task", createdTask.getTitle());
        assertEquals(TaskPriority.HIGH, createdTask.getPriority());
        assertFalse(createdTask.isCompleted());
    }
    
    @Test
    void testGetTaskById() {
        Task task = new Task("Test Task", TaskPriority.MEDIUM);
        Task createdTask = taskService.addTask(task);
        
        Optional<Task> retrievedTask = taskService.getTaskById(createdTask.getId());
        
        assertTrue(retrievedTask.isPresent());
        assertEquals(createdTask.getId(), retrievedTask.get().getId());
        assertEquals("Test Task", retrievedTask.get().getTitle());
    }
    
    @Test
    void testUpdateTask() {
        Task task = new Task("Original Task", TaskPriority.LOW);
        Task createdTask = taskService.addTask(task);
        
        Task updateData = new Task();
        updateData.setTitle("Updated Task");
        updateData.setPriority(TaskPriority.HIGH);
        updateData.setCompleted(true);
        
        Optional<Task> updatedTask = taskService.updateTask(createdTask.getId(), updateData);
        
        assertTrue(updatedTask.isPresent());
        assertEquals("Updated Task", updatedTask.get().getTitle());
        assertEquals(TaskPriority.HIGH, updatedTask.get().getPriority());
        assertTrue(updatedTask.get().isCompleted());
    }
    
    @Test
    void testDeleteTask() {
        Task task = new Task("Task to Delete", TaskPriority.MEDIUM);
        Task createdTask = taskService.addTask(task);
        
        boolean deleted = taskService.deleteTask(createdTask.getId());
        assertTrue(deleted);
        
        Optional<Task> retrievedTask = taskService.getTaskById(createdTask.getId());
        assertFalse(retrievedTask.isPresent());
    }
    
    @Test
    void testSearchTasks() {
        Task task1 = new Task("Java Programming", TaskPriority.HIGH);
        Task task2 = new Task("Python Scripting", TaskPriority.MEDIUM);
        Task task3 = new Task("Web Development", TaskPriority.LOW);
        
        taskService.addTask(task1);
        taskService.addTask(task2);
        taskService.addTask(task3);
        
        List<Task> searchResults = taskService.searchTasks("Programming");
        assertFalse(searchResults.isEmpty());
        assertTrue(searchResults.stream().anyMatch(t -> t.getTitle().contains("Programming")));
    }
    
    @Test
    void testGetTasksByPriority() {
        Task highTask = new Task("High Priority Task", TaskPriority.HIGH);
        Task mediumTask = new Task("Medium Priority Task", TaskPriority.MEDIUM);
        
        taskService.addTask(highTask);
        taskService.addTask(mediumTask);
        
        List<Task> highPriorityTasks = taskService.getTasksByPriority(TaskPriority.HIGH);
        assertFalse(highPriorityTasks.isEmpty());
        assertTrue(highPriorityTasks.stream().allMatch(t -> t.getPriority() == TaskPriority.HIGH));
    }
    
    @Test
    void testGetTaskStats() {
        // Create some test tasks
        Task completedTask = new Task("Completed Task", TaskPriority.HIGH);
        completedTask.setCompleted(true);
        
        Task pendingTask = new Task("Pending Task", TaskPriority.MEDIUM);
        
        taskService.addTask(completedTask);
        taskService.addTask(pendingTask);
        
        TaskService.TaskStats stats = taskService.getTaskStats();
        
        assertTrue(stats.getTotal() >= 2);
        assertTrue(stats.getCompleted() >= 1);
        assertTrue(stats.getPending() >= 1);
    }
}
