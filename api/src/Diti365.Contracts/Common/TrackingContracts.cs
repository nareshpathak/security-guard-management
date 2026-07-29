namespace Diti365.Contracts.Common;

/// <summary>
/// One entry from the phone's location outbox.
///
/// `IsMockLocation` is reported by the device rather than trusted as proof of
/// honesty: a spoofed ping is uploaded and stored flagged, so the attempt leaves
/// a trace. The server never lets a flagged ping count as a real position.
/// </summary>
public sealed record LocationPing(
    decimal Latitude,
    decimal Longitude,
    DateTime LoggedAt,
    decimal? Accuracy = null,
    decimal? Speed = null,
    byte? BatteryLevel = null,
    string? Source = "FG",
    bool IsMockLocation = false);
