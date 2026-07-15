"use client";
import { useState } from "react";
import { Star } from "lucide-react";

interface StarRatingProps {
  value: number;
  onChange?: (value: number) => void;
  size?: number;
  /** Render a non-interactive display of the rating. */
  readOnly?: boolean;
}

/** Simple 1–5 star rating — interactive input, or read-only display when `readOnly`. */
export default function StarRating({ value, onChange, size = 32, readOnly = false }: StarRatingProps) {
  const [hover, setHover] = useState(0);
  const active = readOnly ? value : hover || value;

  if (readOnly) {
    return (
      <div className="flex items-center gap-1.5">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            size={size}
            className={
              star <= active ? "fill-amber-400 text-amber-400" : "fill-transparent text-gray-300"
            }
          />
        ))}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-1.5" onMouseLeave={() => setHover(0)}>
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          onMouseEnter={() => setHover(star)}
          onClick={() => onChange?.(star)}
          className="transition-transform hover:scale-110"
          aria-label={`${star} stars`}
        >
          <Star
            size={size}
            className={
              star <= active ? "fill-amber-400 text-amber-400" : "fill-transparent text-gray-300"
            }
          />
        </button>
      ))}
    </div>
  );
}
