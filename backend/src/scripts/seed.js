require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const SpatialObject = require('../models/SpatialObject');

const TOTAL_OBJECTS = 10000;
const COORD_MIN = -10000;
const COORD_MAX = 10000;
const COLORS = ['#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6'];
const SHAPES = ['circle', 'square', 'triangle'];

function randomInRange(min, max) {
  return Math.random() * (max - min) + min;
}

function generateObjects(count) {
  const objects = [];
  for (let i = 0; i < count; i++) {
    objects.push({
      loc: [randomInRange(COORD_MIN, COORD_MAX), randomInRange(COORD_MIN, COORD_MAX)],
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      shape: SHAPES[Math.floor(Math.random() * SHAPES.length)],
      size: Math.floor(randomInRange(4, 12)),
    });
  }
  return objects;
}

async function seed() {
  await connectDB();

  console.log('Clearing existing objects...');
  await SpatialObject.deleteMany({});

  console.log(`Generating ${TOTAL_OBJECTS} objects...`);
  const objects = generateObjects(TOTAL_OBJECTS);

  console.log('Inserting into MongoDB...');
  await SpatialObject.insertMany(objects); // bulk insert — one round trip, not 10k

  const count = await SpatialObject.countDocuments();
  console.log(`Seed complete. Total objects in DB: ${count}`);

  await mongoose.disconnect();
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});