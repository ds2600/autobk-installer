# Use Ubuntu as a base image
FROM ubuntu:latest

# Update the package list
RUN apt update

# Ensure wget and sudo are installed
RUN apt install -y wget sudo

# Copy the script and .env file into the container
COPY install.sh /install.sh
COPY .env /.env

# Make the script executable
RUN chmod +x /install.sh

# Run the script
CMD ["/install.sh"]