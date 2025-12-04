import { serve } from "std/server";
import { createClient } from "@supabase/supabase-js";

// Environment variables
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Allowed task types
const ALLOWED_TYPES = ["call", "email", "review"];

// Supabase client (Service Role Key)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const body = await req.json().catch(() => null);

    if (!body) {
      return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });
    }

    const { application_id, task_type, due_at, title, description } = body;

    // Validation
    if (!application_id) {
      return new Response(JSON.stringify({ error: "application_id is required" }), { status: 400 });
    }

    if (!task_type || !ALLOWED_TYPES.includes(task_type)) {
      return new Response(
        JSON.stringify({ error: "task_type must be one of: call, email, review" }),
        { status: 400 }
      );
    }

    if (!due_at) {
      return new Response(JSON.stringify({ error: "due_at is required" }), { status: 400 });
    }

    const dueDate = new Date(due_at);
    if (isNaN(dueDate.getTime())) {
      return new Response(JSON.stringify({ error: "due_at must be an ISO timestamp" }), {
        status: 400,
      });
    }

    const now = new Date();
    if (dueDate <= now) {
      return new Response(JSON.stringify({ error: "due_at must be in the future" }), {
        status: 400,
      });
    }

    // Insert task
    const insertPayload = {
      related_id: application_id,
      related_table: "applications",
      title: title ?? `${task_type} task`,
      description: description ?? null,
      type: task_type,
      due_at: dueDate.toISOString(),
      status: "pending",
    };

    const { data, error: insertError } = await supabase
      .from("tasks")
      .insert(insertPayload)
      .select("id")
      .single();

    if (insertError) {
      console.error("Insert Error:", insertError);
      return new Response(JSON.stringify({ error: "Failed to insert task" }), { status: 500 });
    }

    const task_id = data.id;

    // Broadcast task.created event
    try {
      const payload = {
        task_id,
        application_id,
        task_type,
        due_at: dueDate.toISOString(),
      };

      const { error: rpcError } = await supabase.rpc("broadcast_notification", {
        channel: "task.created",
        payload,
      });

      if (rpcError) {
        console.warn("RPC Broadcast Error:", rpcError);
      }
    } catch (e) {
      console.warn("Broadcast exception:", e);
    }

    return new Response(JSON.stringify({ success: true, task_id }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unhandled error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), { status: 500 });
  }
});
