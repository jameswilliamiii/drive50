// The stylesheets own the timings. JS that has to wait for one reads it from the
// token rather than restating the number, so retuning the CSS cannot leave a
// controller tearing an element out mid-transition.
export function motionDuration(token, fallback) {
  const raw = getComputedStyle(document.documentElement).getPropertyValue(token).trim()
  const ms = raw.endsWith("ms") ? parseFloat(raw) : raw.endsWith("s") ? parseFloat(raw) * 1000 : NaN

  return Number.isFinite(ms) ? ms : fallback
}
