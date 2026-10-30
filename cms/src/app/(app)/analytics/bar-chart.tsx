/**
 * A small bar chart drawn in SVG. The numbers are also in a table for screen
 * readers, so the chart itself is hidden from them.
 */
export function BarChart({
  title,
  points,
  unit,
}: {
  title: string;
  points: { label: string; value: number }[];
  unit: string;
}) {
  const max = Math.max(1, ...points.map((p) => p.value));
  const W = 600;
  const H = 110;
  const gap = points.length > 45 ? 1 : 2;
  const barW = (W - gap * (points.length - 1)) / points.length;
  const total = points.reduce((n, p) => n + p.value, 0);
  const first = points[0]?.label;
  const last = points.at(-1)?.label;

  return (
    <figure className="flex flex-col gap-2">
      <figcaption className="flex items-baseline justify-between gap-3">
        <span className="font-medium">{title}</span>
        <span className="text-xs text-muted">
          {total.toLocaleString('en-IN')} {unit} in total · busiest day {max.toLocaleString('en-IN')}
        </span>
      </figcaption>
      <svg viewBox={`0 0 ${W} ${H + 18}`} className="w-full" aria-hidden="true">
        <line x1="0" x2={W} y1={H} y2={H} className="stroke-border" strokeWidth="1" />
        {points.map((p, i) => {
          const h = p.value === 0 ? 0 : Math.max(2, (p.value / max) * (H - 4));
          return (
            <rect key={p.label} x={i * (barW + gap)} y={H - h} width={barW} height={h} rx="1.5" className="fill-primary">
              <title>{`${p.label}: ${p.value} ${unit}`}</title>
            </rect>
          );
        })}
        <text x="0" y={H + 14} className="fill-muted text-[11px]">{first}</text>
        <text x={W} y={H + 14} textAnchor="end" className="fill-muted text-[11px]">{last}</text>
      </svg>
      <table className="sr-only">
        <caption>{title}</caption>
        <thead>
          <tr>
            <th>Day</th>
            <th>{unit}</th>
          </tr>
        </thead>
        <tbody>
          {points.map((p) => (
            <tr key={p.label}>
              <td>{p.label}</td>
              <td>{p.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}
