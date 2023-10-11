# Debug Mode Guide

Steps to enter and exit debug mode in dev environment

**WARNING:** Never under any circumstance follow these instructions on a live
server when there is sensitive or production data in the database!

## Prerequisites
- Navigate to the `dtrack/ui` directory
- Upon switching from dev to debug and visa versa, you will need to clear
  browser cache (a browser extension is recommended)

## Local Environment
1. `yarn debug`
1. `yarn dev`

### Containerized Environment
1. `./run.sh debug`
1. `./run.sh dev`
