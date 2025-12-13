const express = require('express');
const app = express();
app.use(express.json());

// In-memory storage (use database in production)
let cloudyUsers = {};

// POST /cloudy-users - Register user presence
app.post('/cloudy-users', (req, res) => {
    const { userId, username, jobId, timestamp } = req.body;
    
    if (!userId || !jobId) {
        return res.status(400).json({ error: 'Missing userId or jobId' });
    }
    
    // Store user data
    cloudyUsers[userId] = {
        userId: userId,
        username: username,
        jobId: jobId,
        timestamp: timestamp || Date.now()
    };
    
    // Clean old entries (older than 60 seconds)
    const now = Date.now() / 1000;
    Object.keys(cloudyUsers).forEach(key => {
        if (now - cloudyUsers[key].timestamp > 60) {
            delete cloudyUsers[key];
        }
    });
    
    res.json({ success: true, message: 'User registered' });
});

// GET /cloudy-users?jobId=XXX - Get users in a server
app.get('/cloudy-users', (req, res) => {
    const { jobId } = req.query;
    
    if (!jobId) {
        return res.status(400).json({ error: 'Missing jobId parameter' });
    }
    
    // Filter users by jobId
    const usersInJob = Object.values(cloudyUsers).filter(user => user.jobId === jobId);
    
    res.json({ users: usersInJob });
});

app.listen(3000);
