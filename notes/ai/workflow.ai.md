```markdown
# 🤝 SimuleOs — Collaboration Workflow Summary

This document summarizes the workflow and conventions for collaborating between **Human (Author)** and **ChatGPT (GPT-5 Assistant)** within the **SimuleOs Project**.

---

## 🧭 Purpose

To establish a clear, structured way to co-develop a complex project (like the Data Handling Framework) by separating **human-authored design notes** from **AI-generated structured documents**, ensuring clarity, control, and consistent organization.

---

## 🧩 Project Structure

```
/project-root/
│
├── project_config.yaml          # Collaboration rules and settings
├── README.md                    # Overview of the project
│
├── /docs/
│   ├── 01_design_notes/         # Human-authored drafts (read-only for AI)
│   ├── 02_generated_docs/       # AI-generated syntheses/summaries
│   └── 03_references/           # External resources or supporting material
│
├── /src/                        # Framework source code
├── /data/                       # Datasets or configuration files
└── /automation/                 # Optional scripts or scheduled tasks
```

---

## 🧾 Roles & Permissions

| Role | Responsibility |
|------|----------------|
| **Human (Author)** | Writes raw ideas, designs, and decisions. Maintains conceptual control. |
| **ChatGPT (Assistant)** | Reads all content; writes only in approved folders; generates structured docs, summaries, and comments. |

**Permissions Overview**
- **Read-only:** `/docs/01_design_notes/`
- **Editable:** `/docs/02_generated_docs/`, `/docs/03_references/`
- **Commentable:** `/docs/01_design_notes/`

---

## 🪶 Rules of Collaboration

1. Assistant never overwrites or regenerates any file in read-only paths.  
2. For design notes:
   - Assistant can analyze, comment, or generate summaries in `/02_generated_docs/`.
   - Comments or suggestions appear as blockquotes or YAML comments.
3. Every generated document must cite its source notes.
4. The tone and structure must follow the configuration file:
   - Language: English  
   - Tone: Technical, exploratory, iterative  
   - Preferred structure:
     1. Context or Problem Statement  
     2. Ideas / Design Variants  
     3. Selected Approach  
     4. Next Steps  

---

## ⚙️ Project Configuration File (`project_config.yaml`)

Defines:
- Roles and permissions
- Collaboration rules
- Style and tone guidelines
- Optional automation suggestions (e.g., weekly synthesis, cross-linking)

---

## 🧠 Workflow Summary

1. **You** write exploratory or messy ideas in `/docs/01_design_notes/`.
2. **You request**:  
   > “Summarize `/docs/01_design_notes/pipeline_architecture.md`.”
3. **I** read it and create a new file:  
   `/docs/02_generated_docs/pipeline_overview.md`
4. **You** review, refine, or merge insights back into your design layer.
5. Optionally, we automate periodic syntheses or updates.

---

## 🧰 File Management

- Files are stored **within ChatGPT’s cloud Project environment** (not local).  
- You can **create, rename, or delete files** in the right-hand “Files” panel.  
- Use the **“Download Project”** option to export everything locally.  
- You can **upload local files** into the Project to integrate external work.

---

## 🧭 Summary Philosophy

> **Human writes ideas → AI organizes them → Human decides.**  
>  
> ChatGPT acts as a *structured assistant*, transforming your exploratory thinking into organized knowledge — without ever overriding your creative control.

---
```
