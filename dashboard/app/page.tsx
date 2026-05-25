import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen bg-[#1A1208] text-stone-100 flex flex-col items-center justify-center px-6 text-center">
      {/* Logo */}
      <div className="mb-12">
        <h1 className="font-fraunces text-7xl font-black text-[#C47B2B] tracking-tight">
          Hapa
        </h1>
        <p className="font-mono text-xs text-stone-500 tracking-widest uppercase mt-1">
          Business Dashboard
        </p>
      </div>

      {/* Headline */}
      <h2 className="font-fraunces text-3xl md:text-4xl font-bold max-w-2xl leading-tight mb-4">
        Be found by the people{" "}
        <span className="text-[#C47B2B] italic">nearest to you.</span>
      </h2>
      <p className="text-stone-400 max-w-lg text-base mb-12 leading-relaxed">
        Register your business, launch Hapa Boost campaigns, manage bookings,
        and partner with local creators — all in one place.
      </p>

      {/* CTAs */}
      <div className="flex flex-col sm:flex-row gap-4">
        <Link
          href="/auth/register"
          className="font-mono text-xs uppercase tracking-widest bg-[#C47B2B] text-[#1A1208] font-bold px-8 py-4 hover:bg-[#E8A84A] transition-colors"
        >
          Register Your Business
        </Link>
        <Link
          href="/auth/login"
          className="font-mono text-xs uppercase tracking-widest border border-[#C47B2B]/40 text-[#C47B2B] px-8 py-4 hover:bg-[#C47B2B]/10 transition-colors"
        >
          Sign In
        </Link>
      </div>

      {/* Stats row */}
      <div className="mt-24 grid grid-cols-3 gap-16 border-t border-stone-800 pt-12">
        {[
          { num: "10", label: "Cities at launch" },
          { num: "Free", label: "To start" },
          { num: "48hr", label: "Boost goes live" },
        ].map(({ num, label }) => (
          <div key={label} className="text-center">
            <div className="font-fraunces text-3xl font-black text-[#C47B2B]">{num}</div>
            <div className="font-mono text-xs text-stone-500 uppercase tracking-widest mt-1">{label}</div>
          </div>
        ))}
      </div>
    </main>
  );
}
