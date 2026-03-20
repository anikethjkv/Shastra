import React from "react";

export default function IndicatorItem({
  children,
  active = false,
  onClick,
  className = "",
}) {
  return (
    <div
      className={`indicator ${active ? "active" : ""} ${className}`}
      onClick={onClick}
    >
      {children}
    </div>
  );
}