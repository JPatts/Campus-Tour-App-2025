# Campus Tour App - Curator Guide
## Content Management Documentation

---

## Table of Contents
1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Hotspot Management](#hotspot-management)
4. [Content Types](#content-types)
5. [File Structure](#file-structure)
6. [Adding New Hotspots](#adding-new-hotspots)
7. [Editing Existing Hotspots](#editing-existing-hotspots)
8. [Content Guidelines](#content-guidelines)
9. [Testing Your Changes](#testing-your-changes)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Overview

As a Curator for the Campus Tour App, you are responsible for managing the tour content that users experience when they visit Portland State University. This guide will help you understand how to add, edit, and maintain hotspot content through the Git repository system.

### Your Role
- **Content Creation**: Add new hotspots with multimedia content
- **Content Updates**: Modify existing hotspot information
- **Quality Assurance**: Ensure content is accurate and engaging
- **Tour Maintenance**: Keep the tour current and relevant

### What You Can Manage
- Hotspot locations and descriptions
- Photos, videos, and audio content
- Text descriptions and information
- Tour route and flow

---

## Getting Started

### Prerequisites
1. **GitHub Account**: You need a GitHub account to access the repository
2. **Git Knowledge**: Basic understanding of Git commands
3. **Content Creation Tools**: Software for editing images, videos, and text
4. **PSU Knowledge**: Familiarity with campus locations and history

### Repository Access
- **Repository URL**: https://github.com/JPatts/Campus-Tour-App-2025
- **Access Level**: You'll need write access to the repository
- **Branch**: Work on the `main` branch for production changes

### Initial Setup
1. **Clone the Repository**
   ```bash
   git clone https://github.com/JPatts/Campus-Tour-App-2025
   cd Campus-Tour-App-2025
   ```

2. **Navigate to Assets Directory**
   ```bash
   cd campus_tour/assets/hotspots
   ```

3. **Familiarize Yourself with Structure**
   - Each hotspot has its own directory
   - Each directory contains a `hotspot.json` file
   - Each directory has an `Assets/` subdirectory for media files

---

## Hotspot Management

### Understanding Hotspots
A hotspot is a physical location on campus where users can access digital content. Each hotspot consists of:

- **Location Data**: GPS coordinates and radius
- **Basic Information**: Name, description, status
- **Multimedia Content**: Photos, videos, audio, text
- **Metadata**: Creation date, author, etc.

### Hotspot States
- **Active**: Visible to users and functional
- **Inactive**: Hidden from users but preserved
- **Draft**: Under development, not yet ready

---

## Content Types

### Supported Media Formats

#### Images
- **Formats**: JPG, PNG, WebP
- **Recommended Size**: 1920x1080 pixels or smaller
- **File Size**: Under 5MB per image
- **Quality**: High quality, clear images

#### Videos
- **Formats**: MP4, MOV
- **Recommended Resolution**: 1080p or 720p
- **Duration**: 30 seconds to 3 minutes
- **File Size**: Under 50MB per video
- **Codec**: H.264 for best compatibility

#### Audio
- **Formats**: MP3, WAV
- **Quality**: 128kbps or higher
- **Duration**: 30 seconds to 5 minutes
- **File Size**: Under 10MB per audio file

#### Text
- **Formats**: Plain text (.txt) or embedded in JSON
- **Length**: 50-500 words per text feature
- **Content**: Historical information, descriptions, facts

### Content Guidelines by Type

#### Photos
- Use high-quality, well-lit images
- Include people when appropriate (with permission)
- Show the location from multiple angles
- Ensure images are relevant to the location

#### Videos
- Keep videos concise and engaging
- Include narration or captions
- Show the location in context
- Use stable camera work

#### Audio
- Provide clear, professional narration
- Include ambient sounds when appropriate
- Keep audio files focused and relevant
- Ensure good audio quality

#### Text
- Write clear, engaging descriptions
- Include historical context
- Use active voice
- Keep paragraphs short and readable

---

## File Structure

### Directory Organization
```
assets/hotspots/
├── [hotspotName]/
│   ├── hotspot.json          # Hotspot configuration
│   └── Assets/               # Multimedia content
│       ├── photo1.jpg
│       ├── video1.mp4
│       ├── audio1.mp3
│       └── description.txt
```

### JSON Configuration Structure
```json
{
    "hotspotId": "unique_identifier",
    "name": "Human-readable name",
    "description": "Brief description",
    "location": {
        "latitude": 45.510866,
        "longitude": -122.683645,
        "radius": 33.10
    },
    "createdAt": "2025-08-14T12:00:00Z",
    "updatedAt": "2025-08-14T12:00:00Z",
    "status": "active",
    "features": [
        {
            "featureId": "1",
            "type": "photo",
            "content": "Description of content",
            "fileLocation": "filename.ext",
            "postedDate": "Aug 10, 2025",
            "author": "Campus Tour Team"
        }
    ]
}
```

### Field Descriptions

#### Basic Information
- **hotspotId**: Unique identifier (no spaces, lowercase)
- **name**: Display name for users
- **description**: Brief overview of the location
- **status**: "active", "inactive", or "draft"

#### Location Data
- **latitude**: GPS latitude (decimal degrees)
- **longitude**: GPS longitude (decimal degrees)
- **radius**: Detection radius in meters (typically 20-50m)

#### Timestamps
- **createdAt**: When the hotspot was first created
- **updatedAt**: When the hotspot was last modified

#### Features Array
- **featureId**: Unique identifier for each content piece
- **type**: "photo", "video", "audio", or "text"
- **content**: Description of the content
- **fileLocation**: Filename in the Assets directory
- **postedDate**: When the content was added
- **author**: Who created the content

---

## Adding New Hotspots

### Step-by-Step Process

1. **Plan Your Hotspot**
   - Choose a meaningful campus location
   - Determine what content you want to include
   - Gather GPS coordinates for the location
   - Decide on an appropriate detection radius

2. **Create Directory Structure**
   ```bash
   cd campus_tour/assets/hotspots
   mkdir [newHotspotName]
   mkdir [newHotspotName]/Assets
   ```

3. **Add Multimedia Content**
   - Place all media files in the `Assets/` directory
   - Use descriptive filenames
   - Ensure files meet format and size requirements

4. **Create JSON Configuration**
   ```json
   {
       "hotspotId": "newHotspotName",
       "name": "Descriptive Name",
       "description": "Brief description of the location",
       "location": {
           "latitude": 45.510866,
           "longitude": -122.683645,
           "radius": 30.0
       },
       "createdAt": "2025-01-15T10:00:00Z",
       "updatedAt": "2025-01-15T10:00:00Z",
       "status": "active",
       "features": [
           {
               "featureId": "1",
               "type": "photo",
               "content": "Main building photo",
               "fileLocation": "building_photo.jpg",
               "postedDate": "Jan 15, 2025",
               "author": "Your Name"
           }
       ]
   }
   ```

5. **Update Service Configuration**
   - Edit `campus_tour/lib/services/hotspot_service.dart`
   - Add your new hotspot directory to the `hotspotDirectories` list

6. **Test Your Changes**
   - Run the app to verify your hotspot appears
   - Test GPS detection at the physical location
   - Verify all content displays correctly

7. **Commit and Push**
   ```bash
   git add .
   git commit -m "Add new hotspot: [hotspotName]"
   git push origin main
   ```

### Example: Adding a Library Hotspot

```json
{
    "hotspotId": "psuLibrary",
    "name": "PSU Library",
    "description": "The main library at Portland State University, offering extensive resources and study spaces.",
    "location": {
        "latitude": 45.511234,
        "longitude": -122.684567,
        "radius": 40.0
    },
    "createdAt": "2025-01-15T10:00:00Z",
    "updatedAt": "2025-01-15T10:00:00Z",
    "status": "active",
    "features": [
        {
            "featureId": "1",
            "type": "photo",
            "content": "Exterior view of the library building",
            "fileLocation": "library_exterior.jpg",
            "postedDate": "Jan 15, 2025",
            "author": "Campus Tour Team"
        },
        {
            "featureId": "2",
            "type": "video",
            "content": "Virtual tour of the library interior",
            "fileLocation": "library_tour.mp4",
            "postedDate": "Jan 15, 2025",
            "author": "Campus Tour Team"
        },
        {
            "featureId": "3",
            "type": "text",
            "content": "The PSU Library houses over 1.5 million volumes and provides access to extensive digital resources. It features quiet study areas, group study rooms, and computer labs.",
            "fileLocation": "library_info.txt",
            "postedDate": "Jan 15, 2025",
            "author": "Campus Tour Team"
        }
    ]
}
```

---

## Editing Existing Hotspots

### Common Edit Operations

#### Update Basic Information
```json
{
    "name": "Updated Name",
    "description": "Updated description",
    "updatedAt": "2025-01-16T14:30:00Z"
}
```

#### Add New Content
```json
{
    "features": [
        // ... existing features ...
        {
            "featureId": "4",
            "type": "photo",
            "content": "New photo content",
            "fileLocation": "new_photo.jpg",
            "postedDate": "Jan 16, 2025",
            "author": "Your Name"
        }
    ]
}
```

#### Change Location
```json
{
    "location": {
        "latitude": 45.511234,
        "longitude": -122.684567,
        "radius": 35.0
    }
}
```

#### Deactivate Hotspot
```json
{
    "status": "inactive",
    "updatedAt": "2025-01-16T14:30:00Z"
}
```

### Edit Process
1. **Make Changes**: Edit the JSON file and/or add new assets
2. **Update Timestamp**: Change `updatedAt` to current time
3. **Test Changes**: Verify the app displays updates correctly
4. **Commit Changes**: Use descriptive commit messages

---

## Content Guidelines

### Writing Style
- **Tone**: Professional but approachable
- **Voice**: Active voice preferred
- **Length**: Concise but informative
- **Accuracy**: Fact-check all information

### Visual Content
- **Quality**: High-resolution, clear images
- **Composition**: Well-framed, interesting angles
- **Lighting**: Good lighting conditions
- **Relevance**: Content should relate to the location

### Audio Content
- **Clarity**: Clear, professional narration
- **Pacing**: Appropriate speaking speed
- **Background**: Minimal background noise
- **Content**: Engaging and informative

### Accessibility
- **Alt Text**: Provide descriptions for images
- **Captions**: Include captions for videos
- **Readability**: Use clear, readable fonts
- **Contrast**: Ensure good color contrast

---

## Testing Your Changes

### Local Testing
1. **Run the App**
   ```bash
   cd campus_tour
   flutter run
   ```

2. **Check Hotspot Loading**
   - Verify hotspot appears in the list
   - Check that all content loads correctly
   - Test GPS detection (if possible)

3. **Content Verification**
   - Images display properly
   - Videos play without errors
   - Audio files work correctly
   - Text is readable and formatted

### GPS Testing
1. **Physical Location Testing**
   - Visit the actual hotspot location
   - Test GPS detection accuracy
   - Verify content triggers properly
   - Check radius detection

2. **Simulation Testing**
   - Use GPS simulation tools
   - Test edge cases (just inside/outside radius)
   - Verify multiple hotspots work together

### Content Testing
1. **File Format Testing**
   - Verify all file formats are supported
   - Check file size limits
   - Test different image/video resolutions

2. **Performance Testing**
   - Ensure content loads quickly
   - Check memory usage
   - Test on different devices

---

## Best Practices

### Content Creation
- **Quality Over Quantity**: Focus on high-quality content
- **Relevance**: Ensure content relates to the location
- **Engagement**: Make content interesting and informative
- **Accuracy**: Verify all information is correct

### File Management
- **Descriptive Names**: Use clear, descriptive filenames
- **Organization**: Keep files organized in Assets directory
- **Backup**: Keep backups of important content
- **Version Control**: Use Git for all changes

### GPS Accuracy
- **Precise Coordinates**: Use accurate GPS coordinates
- **Appropriate Radius**: Set radius based on location size
- **Testing**: Test GPS detection at physical location
- **Documentation**: Document any GPS-related issues

### Collaboration
- **Communication**: Coordinate with team members
- **Review Process**: Have content reviewed before publishing
- **Documentation**: Document all changes and decisions
- **Backup Plans**: Have backup content ready

---

## Troubleshooting

### Common Issues

#### Hotspot Not Appearing
- **Check Status**: Ensure status is "active"
- **Verify JSON**: Check for syntax errors in JSON file
- **Service Update**: Ensure hotspot is included in service
- **App Restart**: Restart the app after changes

#### Content Not Loading
- **File Path**: Verify file paths in JSON
- **File Format**: Check file format compatibility
- **File Size**: Ensure files are within size limits
- **File Corruption**: Check for corrupted files

#### GPS Issues
- **Coordinates**: Verify GPS coordinates are correct
- **Radius**: Check if radius is appropriate
- **Device GPS**: Ensure device GPS is working
- **Location Services**: Check location permissions

#### Performance Problems
- **File Size**: Reduce file sizes if too large
- **Number of Features**: Limit features per hotspot
- **Image Resolution**: Optimize image resolutions
- **Video Quality**: Compress videos appropriately

### Debug Steps
1. **Check Logs**: Review app logs for errors
2. **Test Incrementally**: Test changes one at a time
3. **Verify Dependencies**: Ensure all files are present
4. **Compare Working Examples**: Compare with working hotspots

### Getting Help
- **Documentation**: Review this guide thoroughly
- **Team Communication**: Contact team members
- **GitHub Issues**: Create issues for bugs
- **Testing**: Test thoroughly before reporting issues

---

## Quick Reference

### File Formats
- **Images**: JPG, PNG, WebP (max 5MB)
- **Videos**: MP4, MOV (max 50MB)
- **Audio**: MP3, WAV (max 10MB)
- **Text**: TXT or embedded in JSON

### JSON Template
```json
{
    "hotspotId": "example",
    "name": "Example Location",
    "description": "Description here",
    "location": {
        "latitude": 45.510866,
        "longitude": -122.683645,
        "radius": 30.0
    },
    "createdAt": "2025-01-15T10:00:00Z",
    "updatedAt": "2025-01-15T10:00:00Z",
    "status": "active",
    "features": []
}
```

### Git Commands
```bash
git add .                           # Stage all changes
git commit -m "Description"         # Commit changes
git push origin main               # Push to repository
git pull origin main               # Get latest changes
```

### Testing Checklist
- [ ] Hotspot appears in app
- [ ] All content loads correctly
- [ ] GPS detection works
- [ ] No errors in console
- [ ] Performance is acceptable

---

*This guide was created for the Campus Tour App capstone project at Portland State University, Summer 2025.*
