// The page-scroll lock has to be reference counted, because more than one thing
// can want it at once and they release independently. Writing
// `document.body.style.overflow` directly meant whoever released last won: a
// Turbo Stream replacing the drives table disconnects a drive-session
// controller, whose teardown cleared the lock out from under an open modal and
// let the page scroll behind it.
//
// Callers pass themselves as the holder, so releasing a claim you never took is
// a no-op rather than someone else's bug.
const holders = new Set()

export function lockScroll(holder) {
  holders.add(holder)
  document.body.style.overflow = "hidden"
}

export function unlockScroll(holder) {
  holders.delete(holder)
  if (holders.size === 0) document.body.style.overflow = ""
}
