---
name: create_log_entry
description: Create a new daily log entry in the content directory.
---

# Create Log Entry

This skill guides the creation of a daily log entry in the `content/log` directory.

## Instructions

1.  **Determine the Date**:
    *   Get the current date (Year, Month, Day).
    *   Construct the target file path: `content/log/[Year]-[Month]-[Day].md`. (Note: Ensure Month and Day are 2 digits, e.g., 2026-02-02.md).

2.  **Check for Existence**:
    *   Check if the file `content/log/[Year]-[Month]-[Day].md` already exists.
    *   If it exists, **STOP** and notify the user that the log for today already exists, asking if they want to append to it or edit it (and wait for further instructions).

3.  **Gather Information**:
    *   If the file does not exist, ask the user for the following information to populate the log:
        *   **Title**: The title of the log entry.
        *   **Summary**: A brief summary of the day or entry.
        *   **Tags**: A list of comma-separated tags (e.g., `update`, `feature`, `fix`).
        *   **Content**: (Optional) Any specific content to start the body of the log with.

4.  **Hardware Check**:
    *   Analyze the provided Summary and Content for references to specific hardware components.
    *   If hardware mentioned matches an existing file in `content/hardware/`, use the wiki link format: `[[component-filename|Component Name]]`.
    *   **Proactive Update**: If the log mentions a status change for a component (e.g., "received the HBA card", "installed the RAM"), ask the user if you should update the `status` in the corresponding hardware file as well.

5.  **Create the File**:
    *   Create the log file using the following template. Omit the `link` field in the frontmatter if no URL is provided.

    ```markdown
    ---
    title: [User Provided Title]
    date: [CURRENT_DATE_ISO8601] (e.g. 2023-10-27T10:00:00Z)
    summary: [User Provided Summary]
    tags: [[User Provided Tags]]
    ---

    # [User Provided Title]

    [User Provided Content or "Start writing here..."]
    ```

6.  **Confirmation**:
    *   Notify the user that the log entry has been created and open the file for them.
    *   If any hardware files were updated during this process, mention those as well.
