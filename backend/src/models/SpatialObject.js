const mongoose = require('mongoose');

const SpatialObjectSchema = new mongoose.Schema({
  loc: {
    type: [Number], // [x, y] — required shape for a 2d index
    required: true,
    validate: {
      validator: (v) => Array.isArray(v) && v.length === 2,
      message: 'loc must be an array of exactly [x, y]',
    },
  },
  color: {
    type: String,
    default: '#3498db',
  },
  shape: {
    type: String,
    enum: ['circle', 'square', 'triangle'],
    default: 'circle',
  },
  size: {
    type: Number,
    default: 8,
  },
}, { timestamps: true }); 

SpatialObjectSchema.index({ loc: '2d' }, { min: -10000, max: 10000 });

module.exports = mongoose.model('SpatialObject', SpatialObjectSchema);