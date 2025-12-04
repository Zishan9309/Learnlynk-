"use client";

import React from "react";
import { createClient } from "@supabase/supabase-js";
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
  useMutation,
  useQueryClient,
} from "@tanstack/react-query";
import { startOfDay, endOfDay } from "date-fns";

// Supabase (frontend)
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

const queryClient = new QueryClient();

// Helper to format date
function formatDate(d: string) {
  return new Date(d).toLocaleString();
}

// Fetch tasks due today
async function fetchTasksToday() {
  const start = startOfDay(new Date()).toISOString();
  const end = endOfDay(new Date()).toISOString();

  const { data, error } = await supabase
    .from("tasks")
    .select("id, title, type, related_id, due_at, status")
    .gte("due_at", start)
    .lte("due_at", end)
    .order("due_at", { ascending: true });

  if (error) throw error;

  return data;
}

// Mark task as completed
async function completeTask(id: string) {
  const { data, error } = await supabase
    .from("tasks")
    .update({
      status: "completed",
      updated_at: new Date().toISOString(),
    })
    .eq("id", id)
    .select("id")
    .single();

  if (error) throw error;

  return data;
}

function TodayTasksList() {
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ["tasks-today"],
    queryFn: fetchTasksToday,
  });

  const mutation = useMutation({
    mutationFn: completeTask,
    onSuccess: () => {
      queryClient.invalidateQueries(["tasks-today"]);
    },
  });

  if (isLoading) return <p>Loading tasks…</p>;
  if (error) return <p>Error: {(error as any).message}</p>;

  return (
    <div className="p-5">
      <h1 className="text-2xl font-bold mb-4">Tasks Due Today</h1>

      {data?.length === 0 && (
        <div className="p-4 border rounded-lg text-center">
          🎉 No tasks due today!
        </div>
      )}

      <table className="min-w-full border mt-4">
        <thead className="bg-gray-200">
          <tr>
            <th className="px-3 py-2 text-left">Title</th>
            <th className="px-3 py-2">Type</th>
            <th className="px-3 py-2">Application ID</th>
            <th className="px-3 py-2">Due At</th>
            <th className="px-3 py-2">Status</th>
            <th className="px-3 py-2">Action</th>
          </tr>
        </thead>

        <tbody>
          {data?.map((task: any) => (
            <tr key={task.id} className="border-t">
              <td className="px-3 py-3">{task.title}</td>
              <td className="px-3 py-3 capitalize">{task.type}</td>
              <td className="px-3 py-3">{task.related_id}</td>
              <td className="px-3 py-3">{formatDate(task.due_at)}</td>
              <td className="px-3 py-3">{task.status}</td>
              <td className="px-3 py-3 text-center">
                <button
                  className="px-3 py-1 border rounded-lg bg-blue-500 text-white disabled:bg-gray-400"
                  disabled={task.status === "completed" || mutation.isLoading}
                  onClick={() => mutation.mutate(task.id)}
                >
                  {task.status === "completed" ? "Completed" : "Complete"}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {mutation.isError && (
        <p className="text-red-500 mt-3">
          Error: {(mutation.error as any).message}
        </p>
      )}
    </div>
  );
}

export default function TodayTasksPage() {
  return (
    <QueryClientProvider client={queryClient}>
      <TodayTasksList />
    </QueryClientProvider>
  );
}
