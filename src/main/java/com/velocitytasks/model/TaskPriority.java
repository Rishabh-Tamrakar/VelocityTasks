package com.velocitytasks.model;

/**
 * Enumeration representing task priority levels.
 */
public enum TaskPriority {
    LOW("Low Priority"),
    MEDIUM("Medium Priority"),
    HIGH("High Priority");

    private final String displayName;

    TaskPriority(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }

    /**
     * Get TaskPriority from string value (case-insensitive)
     */
    public static TaskPriority fromString(String value) {
        if (value == null) {
            return MEDIUM; // Default value
        }
        
        try {
            return TaskPriority.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            return MEDIUM; // Default value if invalid
        }
    }
}
