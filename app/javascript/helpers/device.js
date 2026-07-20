// A hover-capable pointer (mouse/trackpad) marks a desktop-class device; touch
// devices report no hover. Shared so tap-vs-click affordances stay consistent
// across controllers.
export function hasHover() {
  return window.matchMedia("(hover: hover)").matches
}
