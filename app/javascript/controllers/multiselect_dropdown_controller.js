import { Controller } from "@hotwired/stimulus";

// Stimulus controller to manage multi-select dropdown UI states.
// It dynamically updates the visual label (the list of checked options)
// as checkboxes are selected/deselected, avoiding inline javascript.
export default class extends Controller {
  static targets = ["checkbox", "label"];

  connect() {
    // Initial update to display currently selected tags when the page loads
    this.updateLabel();
  }

  // Iterates over all tag checkboxes, filters the checked ones,
  // maps them to their adjacent text label, and joins them with commas.
  updateLabel() {
    const selected = Array.from(this.checkboxTargets)
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.nextElementSibling.textContent.trim());

    this.labelTarget.textContent = selected.length > 0 ? selected.join(", ") : "(none)";
  }
}
