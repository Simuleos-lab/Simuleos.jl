# ============================================================
# 008 — SQLite metadata index queries (curated workflow)
#
# Demonstrates the `@simos sqlite.*` interface for querying
# recorded sessions, commits, scopes, and variables via SQL
# against the auto-built metadata index.
# ============================================================

import Simuleos: @simos

@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false,
))

# ── Record two sessions with different structure ─────────────

@simos session.init("experiment", "alpha-run")

let
    lr = 0.01
    epochs = 100
    @simos stage.inline(lr, epochs)
    @simos stage.meta(phase = "config")
    @simos scope.capture("config")
    @simos session.commit("setup")
end

for step in 1:3
    let step = step
        loss = round(1.0 / step; digits = 4)
        accuracy = round(1.0 - loss; digits = 4)
        @simos stage.inline(step, loss, accuracy)
        @simos stage.meta(phase = "train", step = step)
        @simos scope.capture("train")
        @simos session.queue("train-step")
    end
end

@simos session.close("alpha-done")

@simos session.init("experiment", "beta-run")

let
    lr = 0.001
    epochs = 200
    big_model = [rand(10, 10) for _ in 1:5]
    @simos stage.inline(lr, epochs)
    @simos stage.blob(big_model)
    @simos stage.meta(phase = "config")
    @simos scope.capture("config")
    @simos session.commit("setup")
end

for step in 1:2
    let step = step
        loss = round(0.5 / step; digits = 4)
        @simos stage.inline(step, loss)
        @simos stage.meta(phase = "train", step = step)
        @simos scope.capture("train")
        @simos session.queue("train-step")
    end
end

@simos session.close("beta-done")

# ── Open the SQLite index (auto-refresh from tapes) ─────────

db = @simos sqlite.open(; sync = :refresh)
println("index path = ", @simos sqlite.path())

# ── Query 1: session overview ────────────────────────────────

println("\n== Sessions ==")
for row in @simos sqlite.execute("""
    SELECT session_labels_csv, commit_count, scope_count
    FROM v_sessions
    ORDER BY session_labels_csv
""")
    println("  ", row[:session_labels_csv],
        ": commits=", row[:commit_count],
        " scopes=", row[:scope_count])
end

# ── Query 2: commits by label pattern ────────────────────────

println("\n== Train Commits ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, c.commit_ord, c.commit_label,
           COUNT(sc.scope_uid) AS scope_count
    FROM commits c
    JOIN v_sessions vs ON c.session_id = vs.session_id
    LEFT JOIN scopes sc ON c.commit_uid = sc.commit_uid
    WHERE c.commit_label LIKE ?
    GROUP BY c.commit_uid
    ORDER BY vs.session_labels_csv, c.commit_ord
""", ("train%",))
    println("  [", row[:session_labels_csv], "] #", row[:commit_ord],
        " ", row[:commit_label], " (", row[:scope_count], " scopes)")
end

# ── Query 3: scope inventory with labels ─────────────────────

println("\n== Scopes Labeled 'config' ==")
for row in @simos sqlite.execute("""
    SELECT session_labels_csv, commit_label, scope_var_count
    FROM v_scope_inventory si
    JOIN v_sessions vs ON si.session_id = vs.session_id
    WHERE scope_labels_csv LIKE '%config%'
    ORDER BY vs.session_labels_csv
""")
    println("  [", row[:session_labels_csv], "] commit=", row[:commit_label],
        " vars=", row[:scope_var_count])
end

# ── Query 4: variable inventory (types and storage modes) ────

println("\n== Variables Named 'loss' ==")
for row in @simos sqlite.execute("""
    SELECT vi.session_label, vi.commit_label, vi.var_name,
           vi.type_short, vi.storage_kind, vi.scope_level,
           vs.session_labels_csv
    FROM v_scope_vars_inventory vi
    JOIN v_sessions vs ON vi.session_id = vs.session_id
    WHERE vi.var_name = 'loss'
    ORDER BY vs.session_labels_csv, vi.commit_ord
""")
    println("  [", row[:session_labels_csv], "] ", row[:var_name],
        " : ", row[:type_short],
        " (", row[:storage_kind], "/", row[:scope_level], ")",
        " @ ", row[:commit_label])
end

# ── Query 5: find blob variables ─────────────────────────────

println("\n== Blob-Stored Variables ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, vi.var_name, vi.type_short,
           vi.blob_ref, vi.commit_label
    FROM v_scope_vars_inventory vi
    JOIN v_sessions vs ON vi.session_id = vs.session_id
    WHERE vi.storage_kind = 'blob'
    ORDER BY vs.session_labels_csv
""")
    bref = string(row[:blob_ref])
    ref_short = length(bref) > 12 ? bref[1:12] * "..." : bref
    println("  [", row[:session_labels_csv], "] ", row[:var_name],
        " : ", row[:type_short], " blob=", ref_short,
        " @ ", row[:commit_label])
end

# ── Query 6: scope metadata queries ─────────────────────────

println("\n== Scope Metadata: phase='train' with step > 1 ==")
for row in @simos sqlite.execute("""
    SELECT vs.session_labels_csv, m1.commit_label, m2.value_text AS step
    FROM v_scope_meta_inventory m1
    JOIN scope_meta_kv m2 ON m1.scope_uid = m2.scope_uid AND m2.meta_key = 'step'
    JOIN v_sessions vs ON m1.session_id = vs.session_id
    WHERE m1.meta_key = 'phase' AND m1.value_text = 'train'
      AND CAST(m2.value_text AS INTEGER) > 1
    ORDER BY vs.session_labels_csv, CAST(m2.value_text AS INTEGER)
""")
    println("  [", row[:session_labels_csv], "] ", row[:commit_label], " step=", row[:step])
end

# ── Query 7: aggregations ───────────────────────────────────

println("\n== Variable Type Distribution ==")
for row in @simos sqlite.execute("""
    SELECT type_short, storage_kind, COUNT(*) AS n
    FROM v_scope_vars_inventory
    GROUP BY type_short, storage_kind
    ORDER BY n DESC
""")
    println("  ", row[:type_short], " (", row[:storage_kind], "): ", row[:n])
end

# ── Query 8: tape-level health check ────────────────────────

println("\n== Tape Index State ==")
for row in @simos sqlite.execute("""
    SELECT subsystem_id, logical_owner_id, refresh_mode, drift_status,
           last_indexed_record_ord
    FROM v_tape_index_state
    ORDER BY subsystem_id, logical_owner_id
""")
    println("  [", row[:subsystem_id], "] ", row[:logical_owner_id],
        " mode=", row[:refresh_mode], " drift=", row[:drift_status],
        " records=", row[:last_indexed_record_ord])
end

# ── Query 9: parameterized execution with bound params ──────

println("\n== Commits per Session (parameterized) ==")
for label in ["alpha-run", "beta-run"]
    for row in @simos sqlite.execute("""
        SELECT COUNT(*) AS n FROM commits c
        JOIN session_labels sl ON c.session_id = sl.session_id
        WHERE sl.label = ?
    """, (label,))
        println("  ", label, ": ", row[:n], " commits")
    end
end

# ── Cleanup ──────────────────────────────────────────────────

@simos sqlite.close()
@simos system.reset()
println("\nDone.")
