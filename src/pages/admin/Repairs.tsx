import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { Wrench, Clock, DollarSign, CircleCheck as CheckCircle2, Calendar as CalendarIcon, ChevronLeft, ChevronRight } from "lucide-react";
import { format, parseISO } from "date-fns";

const PAGE_SIZE = 10;

interface RepairRow {
  id: string;
  repair_date: string | null;
  description: string | null;
  cost: number | null;
  company: string | null;
  status: string;
  resolved: boolean;
  damage_marker_id: string | null;
  vehicle_id: string;
  vehicle: { registration_number: string; make: string | null; model: string | null } | null;
  damage_marker: { description: string | null; damage_type: string | null; id: string } | null;
}

function fmtCurrency(v: number | null) {
  if (v == null) return "—";
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(v);
}

function fmtDate(d: string | null) {
  if (!d) return "—";
  try {
    return format(parseISO(d), "MMM d, yyyy");
  } catch {
    return d;
  }
}

export default function AdminRepairs() {
  const qc = useQueryClient();

  const { data, isLoading } = useQuery<RepairRow[]>({
    queryKey: ["repairs-maintenance"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("vehicle_repairs")
        .select(
          "id, repair_date, description, cost, company, status, resolved, damage_marker_id, vehicle_id, vehicle:vehicles(registration_number, make, model), damage_marker:damage_markers(description, damage_type, id)",
        )
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data || []) as RepairRow[];
    },
  });

  const all = data || [];
  const beingRepaired = all.filter((r) => r.status === "being_repaired");
  const repaired = all.filter((r) => r.status === "repaired");

  const totalCost = all.reduce((sum, r) => sum + (r.cost ? Number(r.cost) : 0), 0);
  const completionRate = all.length > 0 ? Math.round((repaired.length / all.length) * 100) : 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Repairs &amp; Maintenance</h1>
        <p className="text-sm text-muted-foreground">
          Track and manage repair records linked to approved damage reports
        </p>
      </div>

      {/* Summary Cards */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card className="p-4">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Total Pending Repairs
              </p>
              <p className="mt-1 text-2xl font-bold">{beingRepaired.length}</p>
            </div>
            <div className="rounded-lg bg-amber-500/10 p-2">
              <Clock className="h-5 w-5 text-amber-600" />
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Total Cost
              </p>
              <p className="mt-1 text-2xl font-bold">{fmtCurrency(totalCost)}</p>
            </div>
            <div className="rounded-lg bg-blue-500/10 p-2">
              <DollarSign className="h-5 w-5 text-blue-600" />
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Completion Rate
              </p>
              <p className="mt-1 text-2xl font-bold">{completionRate}%</p>
            </div>
            <div className="rounded-lg bg-green-500/10 p-2">
              <CheckCircle2 className="h-5 w-5 text-green-600" />
            </div>
          </div>
        </Card>
      </div>

      {isLoading ? (
        <Card className="p-8 text-center text-sm text-muted-foreground">Loading…</Card>
      ) : (
        <Tabs defaultValue="being_repaired">
          <TabsList>
            <TabsTrigger value="being_repaired">
              Being Repaired
              <span className="ml-1.5 rounded-full bg-amber-500 px-1.5 text-xs text-white">
                {beingRepaired.length}
              </span>
            </TabsTrigger>
            <TabsTrigger value="repaired">
              Repaired
              <span className="ml-1.5 rounded-full bg-green-500 px-1.5 text-xs text-white">
                {repaired.length}
              </span>
            </TabsTrigger>
          </TabsList>

          <TabsContent value="being_repaired" className="mt-4">
            <RepairGroup repairs={beingRepaired} status="being_repaired" qc={qc} />
          </TabsContent>

          <TabsContent value="repaired" className="mt-4">
            <RepairGroup repairs={repaired} status="repaired" qc={qc} />
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}

function RepairGroup({
  repairs,
  status,
  qc,
}: {
  repairs: RepairRow[];
  status: string;
  qc: ReturnType<typeof useQueryClient>;
}) {
  const [page, setPage] = useState(0);

  // Group by vehicle within this status group
  const byVehicle = new Map<string, { vehicle: RepairRow["vehicle"]; rows: RepairRow[] }>();
  for (const r of repairs) {
    const key = r.vehicle_id;
    if (!byVehicle.has(key)) {
      byVehicle.set(key, { vehicle: r.vehicle, rows: [] });
    }
    byVehicle.get(key)!.rows.push(r);
  }

  const vehicleGroups = Array.from(byVehicle.entries());
  const totalPages = Math.max(1, Math.ceil(vehicleGroups.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages - 1);
  const pageGroups = vehicleGroups.slice(currentPage * PAGE_SIZE, (currentPage + 1) * PAGE_SIZE);

  if (repairs.length === 0) {
    return (
      <Card className="p-8 text-center">
        <Wrench className="mx-auto h-10 w-10 text-muted-foreground" />
        <p className="mt-3 font-medium">
          {status === "being_repaired" ? "No pending repairs" : "No completed repairs yet"}
        </p>
        <p className="text-sm text-muted-foreground">
          {status === "being_repaired"
            ? "Approved damage reports will appear here automatically"
            : "Marked-as-repaired records will appear here"}
        </p>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {pageGroups.map(([vehicleId, group]) => (
        <VehicleRepairCard key={vehicleId} vehicleId={vehicleId} group={group} qc={qc} />
      ))}

      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 pt-2">
          <Button
            variant="outline"
            size="sm"
            disabled={currentPage === 0}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
          >
            <ChevronLeft className="h-4 w-4" /> Prev
          </Button>
          <span className="text-sm text-muted-foreground">
            Page {currentPage + 1} of {totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={currentPage >= totalPages - 1}
            onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
          >
            Next <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      )}
    </div>
  );
}

function VehicleRepairCard({
  vehicleId,
  group,
  qc,
}: {
  vehicleId: string;
  group: { vehicle: RepairRow["vehicle"]; rows: RepairRow[] };
  qc: ReturnType<typeof useQueryClient>;
}) {
  const { vehicle, rows } = group;
  const reg = vehicle?.registration_number ?? "Unknown vehicle";
  const name = [vehicle?.make, vehicle?.model].filter(Boolean).join(" ") || "";

  return (
    <Card>
      <div className="flex items-center justify-between border-b px-4 py-3">
        <div className="flex items-center gap-2">
          <p className="font-semibold text-sm">{reg}</p>
          {name && <span className="text-sm text-muted-foreground">{name}</span>}
          <Badge variant="secondary" className="text-xs">{rows.length}</Badge>
        </div>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-40">Linked Damage</TableHead>
            <TableHead className="w-28">Status</TableHead>
            <TableHead className="w-36">Company</TableHead>
            <TableHead className="w-28">Cost</TableHead>
            <TableHead className="w-36">Repair Date</TableHead>
            <TableHead>Description</TableHead>
            <TableHead className="w-32 text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map((r) => (
            <RepairRowEditor key={r.id} repair={r} qc={qc} />
          ))}
        </TableBody>
      </Table>
    </Card>
  );
}

function RepairRowEditor({ repair, qc }: { repair: RepairRow; qc: ReturnType<typeof useQueryClient> }) {
  const [editing, setEditing] = useState(false);
  const [company, setCompany] = useState(repair.company ?? "");
  const [cost, setCost] = useState(repair.cost != null ? String(repair.cost) : "");
  const [repairDate, setRepairDate] = useState<Date | undefined>(
    repair.repair_date ? parseISO(repair.repair_date) : undefined,
  );
  const [description, setDescription] = useState(repair.description ?? "");
  const [saving, setSaving] = useState(false);

  function startEdit() {
    setCompany(repair.company ?? "");
    setCost(repair.cost != null ? String(repair.cost) : "");
    setRepairDate(repair.repair_date ? parseISO(repair.repair_date) : undefined);
    setDescription(repair.description ?? "");
    setEditing(true);
  }

  const saveMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase
        .from("vehicle_repairs")
        .update({
          company: company.trim() || null,
          cost: cost ? parseFloat(cost) : null,
          repair_date: repairDate ? format(repairDate, "yyyy-MM-dd") : null,
          description: description.trim() || null,
        })
        .eq("id", repair.id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Repair updated");
      setEditing(false);
      qc.invalidateQueries({ queryKey: ["repairs-maintenance"] });
      qc.invalidateQueries({ queryKey: ["vehicle-repairs", repair.vehicle_id] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  const markRepairedMutation = useMutation({
    mutationFn: async () => {
      const missing: string[] = [];
      if (!repair.company?.trim()) missing.push("Company");
      if (repair.cost == null) missing.push("Cost");
      if (!repair.repair_date) missing.push("Repair Date");
      if (!repair.description?.trim()) missing.push("Description");
      if (missing.length > 0) {
        throw new Error(`Cannot mark as repaired — missing: ${missing.join(", ")}`);
      }
      const { error } = await supabase
        .from("vehicle_repairs")
        .update({ status: "repaired" })
        .eq("id", repair.id);
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Marked as repaired");
      qc.invalidateQueries({ queryKey: ["repairs-maintenance"] });
      qc.invalidateQueries({ queryKey: ["vehicle-repairs", repair.vehicle_id] });
    },
    onError: (e: Error) => toast.error(e.message),
  });

  if (!editing) {
    return (
      <TableRow className={repair.status === "repaired" ? "opacity-60" : ""}>
        <TableCell className="text-sm">
          {repair.damage_marker
            ? repair.damage_marker.description || repair.damage_marker.damage_type?.replace("_", " ") || "Linked damage"
            : "—"}
        </TableCell>
        <TableCell>
          <Badge
            variant="outline"
            className={
              repair.status === "being_repaired"
                ? "border-amber-500 text-amber-700"
                : "border-green-500 text-green-700"
            }
          >
            {repair.status === "being_repaired" ? "Being Repaired" : "Repaired"}
          </Badge>
        </TableCell>
        <TableCell className="text-sm">{repair.company || "—"}</TableCell>
        <TableCell className="text-sm text-muted-foreground">{fmtCurrency(repair.cost)}</TableCell>
        <TableCell className="text-sm">{fmtDate(repair.repair_date)}</TableCell>
        <TableCell className="max-w-xs text-sm">{repair.description || "—"}</TableCell>
        <TableCell className="text-right">
          <div className="flex justify-end gap-1">
            <Button variant="ghost" size="sm" className="h-7" onClick={startEdit}>
              Edit
            </Button>
            {repair.status === "being_repaired" && (
              <Button
                variant="default"
                size="sm"
                className="h-7 bg-green-600 hover:bg-green-700"
                disabled={markRepairedMutation.isPending}
                onClick={() => markRepairedMutation.mutate()}
              >
                <CheckCircle2 className="mr-1 h-3.5 w-3.5" /> Repaired
              </Button>
            )}
          </div>
        </TableCell>
      </TableRow>
    );
  }

  return (
    <TableRow>
      <TableCell className="text-sm align-top pt-3">
        {repair.damage_marker
          ? repair.damage_marker.description || repair.damage_marker.damage_type?.replace("_", " ") || "Linked damage"
          : "—"}
      </TableCell>
      <TableCell className="align-top pt-3">
        <Badge
          variant="outline"
          className={
            repair.status === "being_repaired"
              ? "border-amber-500 text-amber-700"
              : "border-green-500 text-green-700"
          }
        >
          {repair.status === "being_repaired" ? "Being Repaired" : "Repaired"}
        </Badge>
      </TableCell>
      <TableCell className="align-top">
        <Input
          value={company}
          onChange={(e) => setCompany(e.target.value)}
          placeholder="Company name"
          className="h-8 text-sm"
        />
      </TableCell>
      <TableCell className="align-top">
        <Input
          type="number"
          min="0"
          step="0.01"
          value={cost}
          onChange={(e) => setCost(e.target.value)}
          placeholder="0.00"
          className="h-8 text-sm"
        />
      </TableCell>
      <TableCell className="align-top">
        <Popover>
          <PopoverTrigger asChild>
            <Button variant="outline" className="h-8 w-full justify-start text-sm font-normal">
              <CalendarIcon className="mr-1 h-3.5 w-3.5" />
              {repairDate ? format(repairDate, "MMM d, yyyy") : "Pick date"}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-auto p-0" align="start">
            <Calendar
              mode="single"
              selected={repairDate}
              onSelect={setRepairDate}
            />
          </PopoverContent>
        </Popover>
      </TableCell>
      <TableCell className="align-top">
        <Textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Repair description"
          rows={2}
          className="text-sm"
        />
      </TableCell>
      <TableCell className="text-right align-top">
        <div className="flex justify-end gap-1">
          <Button
            variant="outline"
            size="sm"
            className="h-7"
            disabled={saving || saveMutation.isPending}
            onClick={() => setEditing(false)}
          >
            Cancel
          </Button>
          <Button
            size="sm"
            className="h-7"
            disabled={saving || saveMutation.isPending}
            onClick={() => {
              setSaving(true);
              saveMutation.mutate(undefined, {
                onSettled: () => setSaving(false),
              });
            }}
          >
            {saveMutation.isPending ? "Saving…" : "Save"}
          </Button>
        </div>
      </TableCell>
    </TableRow>
  );
}
