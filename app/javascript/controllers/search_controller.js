import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  
  connect() {
    console.log("Search controller connected")
  }
  
  submit(event) {
    // Debounce is handled in the view
    // This method is here for future enhancements
  }
}