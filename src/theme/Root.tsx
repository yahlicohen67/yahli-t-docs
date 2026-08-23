import React, { type ReactNode } from "react";
import styles from "./Root.module.css";

// Swizzled Root: wraps every page with a fixed watermark badge pinned to
// the bottom-right corner. The watermark image (static/img/watermark.png)
// already bakes in the 12% opacity, so this component just positions it.
export default function Root({ children }: { children: ReactNode }): ReactNode {
  return (
    <>
      <div className={styles.watermarkOverlay} aria-hidden="true" />
      {children}
    </>
  );
}
