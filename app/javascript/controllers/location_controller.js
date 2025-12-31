import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "latitude", "longitude", "status"]

  requestLocation(event) {
    if (!navigator.geolocation) {
      alert("Geolocation is not supported by your browser")
      return
    }

    const button = event.target
    const originalText = button.textContent
    button.disabled = true
    button.textContent = "Getting location..."

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.latitudeTarget.value = position.coords.latitude
        this.longitudeTarget.value = position.coords.longitude
        this.formTarget.requestSubmit()
      },
      (error) => {
        button.disabled = false
        button.textContent = originalText

        let message = "Unable to get your location. "
        switch(error.code) {
          case error.PERMISSION_DENIED:
            message += "Please allow location access in your browser settings."
            break
          case error.POSITION_UNAVAILABLE:
            message += "Location information is unavailable."
            break
          case error.TIMEOUT:
            message += "Location request timed out."
            break
          default:
            message += "An unknown error occurred."
        }
        alert(message)
      },
      {
        enableHighAccuracy: false,
        timeout: 10000,
        maximumAge: 0
      }
    )
  }

  clearLocation() {
    if (confirm("Are you sure you want to clear your location? Night drive detection will use timezone-based approximation.")) {
      this.latitudeTarget.value = ""
      this.longitudeTarget.value = ""
      this.formTarget.requestSubmit()
    }
  }
}
