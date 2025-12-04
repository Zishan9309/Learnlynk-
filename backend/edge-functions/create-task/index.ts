import { serve } from "std/server";
import { createClient } from "@supabase/supabase-js";

// env vars (set in Supabase Edge Functions)
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ALLOWED_TYPES = ["call", "email", "review"];

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
    }

    const body = await req.json().catch(() => null);
    if (!body) return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });

    const { application_id, task_type, due_at, title, description, tenant_id } = body;

    if (!application_id) return new Response(JSON.stringify({ error: "application_id is required" }), { status: 400 });
    if (!task_type || !ALLOWED_TYPES.includes(task_type)) {
      return new Response(JSON.stringify({ error: "task_type must be one of call,email,review" }), { status: 400 });
    }
    if (!due_at) return new Response(JSON.stringify({ error: "due_at is required" }), { status: 400 });

    const dueDate = new Date(due_at);
    if (isNaN(dueDate.getTime())) return new Response(JSON.stringify({ error: "due_at must be a valid ISO timestamp" }), { status: 400 });
    if (dueDate <= new Date()) return new Response(JSON.stringify({ error: "due_at must be in the future" }), { status: 400 });

    // payload to insert
    const payload: any = {
      application_id,
      title: title ?? `${task_type} task`,
      description: description ?? null,
      type: task_type,
      due_at: dueDate.toISOString(),
      status: "pending",
    };
    if (tenant_id) payload.tenant_id = tenant_id;

    const { data, error: insertError } = await supabase
      .from("tasks")
      .insert(payload)
      .select("id")
      .single();

    if (insertError) {
      console.error("Insert error", insertError);
      return new Response(JSON.stringify({ error: "Failed to insert task" }), { status: 500 });
    }

    const task_id = data.id;

    // broadcast optional (non-fatal)
    try {
      const rpcPayload = {
        task_id,
        application_id,
        type: task_type,
        due_at: dueDate.toISOString(),
      };
      const { error: rpcErr } = await supabase.rpc("broadcast_notification", {
        channel: "task.created",
        payload: rpcPayload,
      });
      if (rpcErr) console.warn("broadcast_notification rpc error", rpcErr);
    } catch (e) {
      console.warn("broadcast failed", e);
    }

    return new Response(JSON.stringify({ success: true, task_id }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (err) {
    console.error("Unhandled error", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), { status: 500 });
  }
});
