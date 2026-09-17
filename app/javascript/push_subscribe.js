export function isPushSupported() {
  return "serviceWorker" in navigator && "PushManager" in window
}

export function iosNeedsHomeScreenInstall() {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream
  if (!isIOS) return false

  const isStandalone = window.navigator.standalone ||
    window.matchMedia("(display-mode: standalone)").matches

  return !isStandalone
}

export async function subscribeToPush({ headers } = {}) {
  const permission = await Notification.requestPermission()

  if (permission !== "granted") {
    throw new Error("Notification permission denied")
  }

  const response = await fetch("/push_subscription/new")
  const { public_key } = await response.json()

  const registration = await navigator.serviceWorker.ready
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(public_key)
  })

  const saveResponse = await fetch("/push_subscription", {
    method: "POST",
    headers: headers || defaultHeaders(),
    body: JSON.stringify({ subscription: subscription.toJSON() })
  })

  if (!saveResponse.ok) {
    throw new Error("Failed to save subscription")
  }

  return subscription
}

function defaultHeaders() {
  const headers = { "Content-Type": "application/json" }
  const token = document.querySelector("[name='csrf-token']")
  if (token) {
    headers["X-CSRF-Token"] = token.content
  }
  return headers
}

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding)
    .replace(/\-/g, "+")
    .replace(/_/g, "/")

  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }

  return outputArray
}
