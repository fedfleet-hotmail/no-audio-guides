import { supabase } from "@/lib/supabase";

/**
 * Ensures a vehicle_repairs record exists for the given damage marker.
 * Called when a damage marker transitions to status = 'approved'.
 *
 * - If a repair record already exists for this damage_marker_id, reuse it
 *   and reset its status to 'being_repaired' (in case it was previously repaired).
 * - If none exists, insert a new one with empty editable fields.
 *
 * Rejected damages must never call this function.
 */
export async function ensureRepairRecord(damageMarkerId: string, vehicleId: string) {
  const { data: existing } = await supabase
    .from("vehicle_repairs")
    .select("id, status")
    .eq("damage_marker_id", damageMarkerId)
    .maybeSingle();

  if (existing) {
    if (existing.status !== "being_repaired") {
      const { error } = await supabase
        .from("vehicle_repairs")
        .update({ status: "being_repaired" })
        .eq("id", existing.id);
      if (error) throw error;
    }
    return;
  }

  const { error } = await supabase.from("vehicle_repairs").insert({
    damage_marker_id: damageMarkerId,
    vehicle_id: vehicleId,
    status: "being_repaired",
  });
  if (error) throw error;
}
