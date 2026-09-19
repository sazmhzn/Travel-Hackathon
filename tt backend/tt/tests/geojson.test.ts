import { describe, it, expect } from 'vitest';
import {
  parseGeoJsonLineString,
  parseGpx,
  bboxToPolygonWkt,
  coordinatesToLineStringWkt,
} from '../src/utils/geojson.js';

describe('GeoJSON and GPX Spatial Utilities', () => {
  it('should parse a valid GeoJSON LineString and calculate distance & bounding box', () => {
    const geojson = {
      type: 'LineString',
      coordinates: [
        [85.324, 27.7172, 1400], // Kathmandu
        [85.340, 27.7250, 1450],
        [85.360, 27.7300, 1500],
      ],
    };

    const meta = parseGeoJsonLineString(geojson);
    expect(meta.geometry.type).toBe('LineString');
    expect(meta.geometry.coordinates.length).toBe(3);
    expect(meta.totalDistanceMeters).toBeGreaterThan(0);
    expect(meta.elevationGainMeters).toBe(100); // 1450-1400 + 1500-1450 = 100
    expect(meta.bbox).toHaveLength(4);
    expect(meta.bbox[0]).toBe(85.324); // minLng
    expect(meta.bbox[1]).toBe(27.7172); // minLat
  });

  it('should reject invalid GeoJSON or insufficient coordinates', () => {
    expect(() => parseGeoJsonLineString({ type: 'Point', coordinates: [85, 27] })).toThrow();
    expect(() =>
      parseGeoJsonLineString({
        type: 'LineString',
        coordinates: [[85, 27]],
      })
    ).toThrow(/at least 2 coordinate pairs/);
  });

  it('should parse GPX track XML correctly', () => {
    const sampleGpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="TestGPX">
  <trk>
    <name>Himalayan Ridge Trail</name>
    <trkseg>
      <trkpt lat="27.9881" lon="86.9250"><ele>5364</ele></trkpt>
      <trkpt lat="27.9890" lon="86.9260"><ele>5400</ele></trkpt>
      <trkpt lat="27.9900" lon="86.9270"><ele>5450</ele></trkpt>
    </trkseg>
  </trk>
</gpx>`;

    const meta = parseGpx(sampleGpx);
    expect(meta.geometry.type).toBe('LineString');
    expect(meta.geometry.coordinates.length).toBe(3);
    expect(meta.totalDistanceMeters).toBeGreaterThan(0);
    expect(meta.elevationGainMeters).toBe(86); // (5400-5364) + (5450-5400) = 36 + 50 = 86
    expect(meta.bbox[0]).toBeCloseTo(86.925);
  });

  it('should format coordinates into PostGIS LINESTRING WKT', () => {
    const coords = [
      [85.1, 27.1],
      [85.2, 27.2],
    ];
    const wkt = coordinatesToLineStringWkt(coords);
    expect(wkt).toBe('LINESTRING(85.1 27.1, 85.2 27.2)');
  });

  it('should format bounding box into PostGIS POLYGON WKT', () => {
    const bbox: [number, number, number, number] = [85.0, 27.0, 86.0, 28.0];
    const wkt = bboxToPolygonWkt(bbox);
    expect(wkt).toBe('POLYGON((85 27, 86 27, 86 28, 85 28, 85 27))');
  });
});
