package geo

import (
	"fmt"
	"math"
)

const (
	EarthRadiusMeters = 6371000.0
)

// GeoHash bucket precision for feed partitioning (~1.2km × 0.6km cells)
const FeedBucketPrecision = 3

// BucketKey rounds coordinates to a grid cell for feed caching
func BucketKey(lat, lng float64) string {
	return fmt.Sprintf("%.3f:%.3f", roundTo(lat, 3), roundTo(lng, 3))
}

func roundTo(v float64, decimals int) float64 {
	p := math.Pow(10, float64(decimals))
	return math.Round(v*p) / p
}

// Distance returns distance in metres between two coordinates (Haversine formula)
func Distance(lat1, lng1, lat2, lng2 float64) float64 {
	φ1 := toRad(lat1)
	φ2 := toRad(lat2)
	Δφ := toRad(lat2 - lat1)
	Δλ := toRad(lng2 - lng1)

	a := math.Sin(Δφ/2)*math.Sin(Δφ/2) +
		math.Cos(φ1)*math.Cos(φ2)*
			math.Sin(Δλ/2)*math.Sin(Δλ/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return EarthRadiusMeters * c
}

func toRad(deg float64) float64 {
	return deg * math.Pi / 180
}

// InRadius returns true if the point is within radiusMeters of the centre
func InRadius(centreLat, centreLng, pointLat, pointLng, radiusMeters float64) bool {
	return Distance(centreLat, centreLng, pointLat, pointLng) <= radiusMeters
}

// Bounding box for a radius — used for coarse filtering before precise ST_DWithin
func BoundingBox(lat, lng, radiusMeters float64) (minLat, minLng, maxLat, maxLng float64) {
	Δlat := (radiusMeters / EarthRadiusMeters) * (180 / math.Pi)
	Δlng := Δlat / math.Cos(toRad(lat))
	return lat - Δlat, lng - Δlng, lat + Δlat, lng + Δlng
}

// WKTPoint returns a Well-Known Text point for PostGIS
func WKTPoint(lat, lng float64) string {
	return fmt.Sprintf("SRID=4326;POINT(%f %f)", lng, lat)
}
