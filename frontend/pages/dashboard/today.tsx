import React, { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// helper: start/end of local day in ISO (server stores timestamptz UTC)
function getDayRangeISO() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  return { start: start.toISOString(), end: end.toISOString() };
}

export default function TodayTasksPage() {
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function fetchTasks() {
    setLoading(true);
    setError(null);
    try {
      const { start, end } = getDayRangeISO();

      // since we added due_date column in schema, we can also query by date equality:
      // const todayDate = new Date().toISOString().slice(0,10);
      // .eq('due_date', todayDate)

      const { data, error } = await supabase
        .from("tasks")
        .select("id, application_id, type, due_at, status, title")
        .gte("due_at", start)
        .lte("due_at", end)
        .neq("status", "completed")
        .order("due_at", { ascending: true });

      if (error) throw error;
      setTasks(data ?? []);
    } catch (err: any) {
      console.error(err);
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchTasks();
  }, []);

  async function markComplete(id: string) {
    try {
      const { error } = await supabase.from("tasks").update({ status: "completed" }).eq("id", id);
      if (error) throw error;
      await fetchTasks();
    } catch (err: any) {
      alert("Failed to mark complete: " + (err.message ?? String(err)));
    }
  }

  return (
    <div style={{ padding: 20 }}>
      <h1>Tasks Due Today</h1>
      {loading && <p>Loading…</p>}
      {error && <p style={{ color: "red" }}>{error}</p>}

      {!loading && tasks.length === 0 && <div>🎉 No tasks due today</div>}

      {!loading && tasks.length > 0 && (
        <table style={{ width: "100%", borderCollapse: "collapse", marginTop: 12 }}>
          <thead>
            <tr style={{ textAlign: "left", borderBottom: "1px solid #ddd" }}>
              <th style={{ padding: 8 }}>Title</th>
              <th style={{ padding: 8 }}>Type</th>
              <th style={{ padding: 8 }}>Application ID</th>
              <th style={{ padding: 8 }}>Due at</th>
              <th style={{ padding: 8 }}>Status</th>
              <th style={{ padding: 8 }}>Action</th>
            </tr>
          </thead>
          <tbody>
            {tasks.map((t) => (
              <tr key={t.id} style={{ borderBottom: "1px solid #f0f0f0" }}>
                <td style={{ padding: 8 }}>{t.title}</td>
                <td style={{ padding: 8 }}>{t.type}</td>
                <td style={{ padding: 8 }}>{t.application_id}</td>
                <td style={{ padding: 8 }}>{new Date(t.due_at).toLocaleString()}</td>
                <td style={{ padding: 8 }}>{t.status}</td>
                <td style={{ padding: 8 }}>
                  <button onClick={() => markComplete(t.id)} disabled={t.status === "completed"}>
                    Mark Complete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
