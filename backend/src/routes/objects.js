const express = require('express');
const router = express.Router();
const { getObjectsInViewport, updateObjectPosition } = require('../controllers/objectsController');

router.get('/', getObjectsInViewport);
router.get('/clusters', getClusteredObjects);
router.patch('/:id', updateObjectPosition);

module.exports = router;