"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Calendar, Clock, User, MapPin, Check, X, ChevronDown } from "lucide-react";

type BookingStatus = "pending" | "confirmed" | "cancelled" | "completed";

type Booking = {
  id: string;
  business_id: string;
  business_name: string;
  user_id: string;
  user_name: string;
  user_phone?: string;
  service_name?: string;
  booked_for: string;
  party_size?: number;
  notes?: string;
  status: BookingStatus;
  created_at: string;
  amount_usd?: number;
  creator_name?: string;
};

const STATUS_CONFIG: Record<BookingStatus, { label: string; color: string; bg: string }> = {
  pending: { label: "Pending", color: "text-amber-600", bg: "bg-amber-50 border-amber-200" },
  confirmed: { label: "Confirmed", color: "text-green-600", bg: "bg-green-50 border-green-200" },
  cancelled: { label: "Cancelled", color: "text-red-500", bg: "bg-red-50 border-red-200" },
  completed: { label: "Completed", color: "text-stone-500", bg: "bg-stone-50 border-stone-200" },
};

export default function BookingsPage() {
  const [statusFilter, setStatusFilter] = useState<BookingStatus | "all">("all");
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["bookings", statusFilter],
    queryFn: () =>
      api.get<{ bookings: Booking[] }>(
        `/v1/bookings?status=${statusFilter === "all" ? "" : statusFilter}`
      ),
  });

  const confirmMutation = useMutation({
    mutationFn: (id: string) => api.post(`/v1/bookings/${id}/confirm`, {}),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["bookings"] }),
  });

  const cancelMutation = useMutation({
    mutationFn: (id: string) => api.post(`/v1/bookings/${id}/cancel`, {}),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["bookings"] }),
  });

  const bookings = data?.bookings ?? [];
  const pending = bookings.filter((b) => b.status === "pending").length;

  return (
    <div className="p-8 max-w-5xl">
      <div className="mb-8 flex items-start justify-between">
        <div>
          <h1 className="font-fraunces text-3xl font-bold flex items-center gap-3">
            <Calendar className="text-[#C47B2B]" size={28} />
            Bookings
          </h1>
          <p className="text-stone-500 text-sm mt-1">
            {pending > 0
              ? `${pending} booking${pending > 1 ? "s" : ""} awaiting confirmation`
              : "Manage reservations and appointments"}
          </p>
        </div>

        {/* Status filter */}
        <div className="flex items-center gap-2">
          {(["all", "pending", "confirmed", "completed", "cancelled"] as const).map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`font-mono text-[10px] uppercase tracking-widest px-3 py-1.5 border transition-colors ${
                statusFilter === s
                  ? "border-[#C47B2B] bg-[#C47B2B] text-white"
                  : "border-stone-200 text-stone-500 hover:border-[#C47B2B]/40"
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-white border border-stone-200 p-5 animate-pulse">
              <div className="h-4 bg-stone-100 rounded w-1/4 mb-3" />
              <div className="h-3 bg-stone-100 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : bookings.length === 0 ? (
        <div className="border border-dashed border-stone-300 p-16 text-center">
          <Calendar size={32} className="text-stone-300 mx-auto mb-4" />
          <h3 className="font-fraunces text-xl font-semibold text-stone-700 mb-2">
            No bookings yet
          </h3>
          <p className="text-stone-400 text-sm">
            Bookings made through the Hapa app will appear here.
          </p>
          <p className="text-stone-300 text-xs mt-2">
            Available on Growth tier and above.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {bookings.map((booking) => (
            <BookingRow
              key={booking.id}
              booking={booking}
              onConfirm={() => confirmMutation.mutate(booking.id)}
              onCancel={() => cancelMutation.mutate(booking.id)}
              isActing={
                confirmMutation.isPending || cancelMutation.isPending
              }
            />
          ))}
        </div>
      )}
    </div>
  );
}

function BookingRow({
  booking,
  onConfirm,
  onCancel,
  isActing,
}: {
  booking: Booking;
  onConfirm: () => void;
  onCancel: () => void;
  isActing: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const cfg = STATUS_CONFIG[booking.status];
  const bookedDate = new Date(booking.booked_for);

  return (
    <div className={`bg-white border ${booking.status === "pending" ? "border-amber-200" : "border-stone-200"}`}>
      <div
        className="p-5 flex items-center gap-4 cursor-pointer hover:bg-stone-50 transition-colors"
        onClick={() => setExpanded((e) => !e)}
      >
        {/* Date block */}
        <div className="w-14 text-center shrink-0">
          <div className="font-fraunces text-2xl font-bold text-stone-900 leading-none">
            {bookedDate.getDate()}
          </div>
          <div className="font-mono text-[10px] uppercase tracking-widest text-stone-400">
            {bookedDate.toLocaleString("en", { month: "short" })}
          </div>
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="font-medium text-stone-900 text-sm">{booking.user_name}</span>
            {booking.creator_name && (
              <span className="font-mono text-[10px] uppercase tracking-widest bg-[#C47B2B]/10 text-[#C47B2B] px-1.5 py-0.5">
                via {booking.creator_name}
              </span>
            )}
          </div>
          <div className="flex items-center gap-3 mt-0.5 text-xs text-stone-400 flex-wrap">
            {booking.service_name && (
              <span className="flex items-center gap-1">
                <MapPin size={10} />
                {booking.service_name}
              </span>
            )}
            <span className="flex items-center gap-1">
              <Clock size={10} />
              {bookedDate.toLocaleTimeString("en", { hour: "2-digit", minute: "2-digit" })}
            </span>
            {booking.party_size && (
              <span className="flex items-center gap-1">
                <User size={10} />
                {booking.party_size} {booking.party_size > 1 ? "people" : "person"}
              </span>
            )}
            {booking.amount_usd && (
              <span className="text-stone-500 font-medium">${booking.amount_usd}</span>
            )}
          </div>
        </div>

        <div className="flex items-center gap-3 shrink-0">
          <span className={`font-mono text-[10px] uppercase tracking-widest border px-2 py-1 ${cfg.bg} ${cfg.color}`}>
            {cfg.label}
          </span>

          {booking.status === "pending" && (
            <>
              <button
                onClick={(e) => { e.stopPropagation(); onConfirm(); }}
                disabled={isActing}
                className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest bg-green-600 text-white px-3 py-2 hover:bg-green-700 transition-colors disabled:opacity-40"
              >
                <Check size={11} />
                Confirm
              </button>
              <button
                onClick={(e) => { e.stopPropagation(); onCancel(); }}
                disabled={isActing}
                className="flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest border border-red-300 text-red-500 px-3 py-2 hover:bg-red-50 transition-colors disabled:opacity-40"
              >
                <X size={11} />
                Decline
              </button>
            </>
          )}

          <ChevronDown
            size={14}
            className={`text-stone-400 transition-transform ${expanded ? "rotate-180" : ""}`}
          />
        </div>
      </div>

      {expanded && (
        <div className="border-t border-stone-100 px-5 py-4 bg-stone-50/50 space-y-2">
          {booking.user_phone && (
            <div className="flex items-center gap-2 text-sm">
              <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400 w-20">Phone</span>
              <a href={`tel:${booking.user_phone}`} className="text-stone-700 hover:text-[#C47B2B]">
                {booking.user_phone}
              </a>
            </div>
          )}
          {booking.notes && (
            <div className="flex items-start gap-2 text-sm">
              <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400 w-20 mt-0.5">Notes</span>
              <span className="text-stone-600">{booking.notes}</span>
            </div>
          )}
          <div className="flex items-center gap-2 text-sm">
            <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400 w-20">Booked</span>
            <span className="text-stone-500">
              {new Date(booking.created_at).toLocaleDateString("en", {
                day: "numeric",
                month: "short",
                year: "numeric",
              })}
            </span>
          </div>
          {booking.business_name && (
            <div className="flex items-center gap-2 text-sm">
              <span className="font-mono text-[10px] uppercase tracking-widest text-stone-400 w-20">For</span>
              <span className="text-stone-600">{booking.business_name}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
