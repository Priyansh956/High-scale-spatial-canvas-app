const express = require('express');
const router = express.Router();
const { getObjectsInViewport } = require('../controllers/objectsController');

router.get('/', getObjectsInViewport);

module.exports = router;