import * as turf from '@turf/turf';
import GpxParserPkg from 'gpxparser';

// Support both ESM and CJS default interop
const GpxParserClass: any = (GpxParserPkg as any).default || GpxParserPkg;

export interface RouteGeometry {
  type: 'LineString';
  coordinates: number[][]; // [lng, lat, ele?]
}

export interface RouteMetadata {
  geometry: RouteGeometry;
  totalDistanceMeters: number;
  elevationGainMeters: number;
  bbox: [number, number, number, number]; // [minLng, minLat, maxLng, maxLat]
}

/**
 * Parses a GPX string into GeoJSON LineString and extracts distance, elevation, and bbox.
 */
export function parseGpx(gpxString: string): RouteMetadata {
  const gpx = new GpxParserClass();
  gpx.parse(gpxString);

  if (!gpx.tracks || gpx.tracks.length === 0) {
    throw new Error('GPX data does not contain any valid tracks');
  }

  const track = gpx.tracks[0];
  const coordinates: number[][] = track.points.map((pt: { lon: number; lat: number; ele?: number }) => [
    pt.lon,
    pt.lat,
    pt.ele !== null && pt.ele !== undefined ? pt.ele : 0,
  ]);

  if (coordinates.length < 2) {
    throw new Error('Track must contain at least 2 points to form a LineString');
  }

  const line = turf.lineString(coordinates.map((c) => [c[0], c[1]]));
  const distanceKm = turf.length(line, { units: 'kilometers' });
  const bbox = turf.bbox(line) as [number, number, number, number];

  // Calculate elevation gain
  let elevationGain = 0;
  for (let i = 1; i < coordinates.length; i++) {
    const diff = (coordinates[i][2] || 0) - (coordinates[i - 1][2] || 0);
    if (diff > 0) elevationGain += diff;
  }

  return {
    geometry: {
      type: 'LineString',
      coordinates,
    },
    totalDistanceMeters: Math.round(distanceKm * 1000),
    elevationGainMeters: Math.round(elevationGain),
    bbox,
  };
}

/**
 * Validates and processes a GeoJSON LineString payload.
 */
export function parseGeoJsonLineString(geojson: any): RouteMetadata {
  if (!geojson || geojson.type !== 'LineString' || !Array.isArray(geojson.coordinates)) {
    throw new Error('Invalid GeoJSON: must be of type "LineString" with coordinate array');
  }

  const coordinates: number[][] = geojson.coordinates;
  if (coordinates.length < 2) {
    throw new Error('LineString must have at least 2 coordinate pairs');
  }

  // Validate each coordinate is [lng, lat]
  for (const pt of coordinates) {
    if (typeof pt[0] !== 'number' || typeof pt[1] !== 'number') {
      throw new Error(`Invalid coordinate pair: [${pt}]`);
    }
  }

  const line = turf.lineString(coordinates.map((c) => [c[0], c[1]]));
  const distanceKm = turf.length(line, { units: 'kilometers' });
  const bbox = turf.bbox(line) as [number, number, number, number];

  let elevationGain = 0;
  if (coordinates[0].length >= 3) {
    for (let i = 1; i < coordinates.length; i++) {
      const diff = (coordinates[i][2] || 0) - (coordinates[i - 1][2] || 0);
      if (diff > 0) elevationGain += diff;
    }
  }

  return {
    geometry: {
      type: 'LineString',
      coordinates,
    },
    totalDistanceMeters: Math.round(distanceKm * 1000),
    elevationGainMeters: Math.round(elevationGain),
    bbox,
  };
}

/**
 * Convert [minLng, minLat, maxLng, maxLat] bbox into PostGIS Polygon WKT format
 */
export function bboxToPolygonWkt(bbox: [number, number, number, number]): string {
  const [minLng, minLat, maxLng, maxLat] = bbox;
  return `POLYGON((${minLng} ${minLat}, ${maxLng} ${minLat}, ${maxLng} ${maxLat}, ${minLng} ${maxLat}, ${minLng} ${minLat}))`;
}

/**
 * Convert coordinates array into PostGIS LineString WKT format
 */
export function coordinatesToLineStringWkt(coordinates: number[][]): string {
  const points = coordinates.map((pt) => `${pt[0]} ${pt[1]}`).join(', ');
  return `LINESTRING(${points})`;
}
