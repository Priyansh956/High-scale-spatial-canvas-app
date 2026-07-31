const SpatialObject = require('../models/SpatialObject');
const mongoose = require('mongoose');

const COORD_MIN = -10000;
const COORD_MAX = 10000;
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

async function updateObjectPosition(req, res) {
  const { id } = req.params;
  const { x, y } = req.body;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(400).json({ error: 'Invalid object id' });
  }

  if (
    x === undefined || y === undefined ||
    Number.isNaN(Number(x)) || Number.isNaN(Number(y))
  ) {
    return res.status(400).json({ error: 'x and y must be numbers' });
  }

  const newX = Number(x);
  const newY = Number(y);

  if (newX < COORD_MIN || newX > COORD_MAX || newY < COORD_MIN || newY > COORD_MAX) {
    return res.status(400).json({ error: `Coordinates must be within [${COORD_MIN}, ${COORD_MAX}]` });
  }

  try {
    const updated = await SpatialObject.findByIdAndUpdate(
      id,
      { loc: [newX, newY] },
      { new: true } // return the document AFTER the update, not before
    ).lean();

    if (!updated) {
      return res.status(404).json({ error: 'Object not found' });
    }

    res.json({ object: updated });
  }
  catch (err) {
    console.error('Error updating object position:', err);
    res.status(500).json({ error: 'Failed to update object' });
  }
}

module.exports = { getObjectsInViewport, updateObjectPosition };