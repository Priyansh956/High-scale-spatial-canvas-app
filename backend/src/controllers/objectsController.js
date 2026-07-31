const SpatialObject = require('../models/SpatialObject');

const MAX_RESULTS = 2000; // safety cap regardless of viewport size

async function getObjectsInViewport(req, res) {
  const { minX, minY, maxX, maxY } = req.query;

  // Validate all four params are present and numeric
  const coords = { minX, minY, maxX, maxY };
  for (const [key, val] of Object.entries(coords)) {
    if (val === undefined || Number.isNaN(Number(val))) {
      return res.status(400).json({ error: `Missing or invalid query param: ${key}` });
    }
  }

  const bbox = {
    minX: Number(minX),
    minY: Number(minY),
    maxX: Number(maxX),
    maxY: Number(maxY),
  };

  if (bbox.minX >= bbox.maxX || bbox.minY >= bbox.maxY) {
    return res.status(400).json({ error: 'min values must be less than max values' });
  }

  try {
    const objects = await SpatialObject.find({
      loc: {
        $geoWithin: {
          $box: [
            [bbox.minX, bbox.minY],
            [bbox.maxX, bbox.maxY],
          ],
        },
      },
    })
      .limit(MAX_RESULTS)
      .lean();

    res.json({
      count: objects.length,
      truncated: objects.length === MAX_RESULTS,
      objects,
    });
  } catch (err) {
    console.error('Error fetching objects in viewport:', err);
    res.status(500).json({ error: 'Failed to fetch objects' });
  }
}

module.exports = { getObjectsInViewport };