# Keep hub navigation and start reachable

Existing 234 campaign/29 legacy UI checks protect callbacks and input. Actual native captures show the tab row and PLAY move when switching map/class/codex; long research content scrolls them away. This conflicts with the GDD p060 stable-start requirement.

1. Change ready/hub layout only: fixed tab header, scrolling body, fixed mode summary and PLAY footer inside safe margins.
2. Reuse current per-tab content and callbacks; leave combat/choice/event/result layouts unchanged.
3. Adapt resize handling explicitly instead of assuming every phase margin contains the old ScrollContainer tree.
4. Add layout regression after real process frames: six tabs retain header/footer rectangles, long body scroll leaves PLAY visible, viewport320/390-equivalent never overflows.
5. Capture new hub pages before any further visual edits; rerun existing targeted UI checks and independent visual review. No simulation/profile/catalog changes.
