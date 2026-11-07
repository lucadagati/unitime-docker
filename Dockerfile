# Pinned base image (OpenJDK 11 is available from the standard repositories)
FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget unzip mysql-server mysql-client openjdk-11-jdk-headless

# Clean up APT cache for a smaller image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the JAVA_HOME environment variable
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$PATH

# Copy SQL files for database setup
COPY ./unitime-4.8/doc/mysql/schema.sql /docker-entrypoint-initdb.d/
COPY ./unitime-4.8/doc/mysql/blank-data.sql /docker-entrypoint-initdb.d/
COPY ./unitime-4.8/doc/mysql/woebegon-data.sql /docker-entrypoint-initdb.d/

# Initialize and setup MySQL database
RUN service mysql start && \
    mysql -u root -e "CREATE DATABASE unitime;" && \
    mysql -u root unitime < /docker-entrypoint-initdb.d/schema.sql && \
    mysql -u root unitime < /docker-entrypoint-initdb.d/blank-data.sql && \
    mysql -u root unitime < /docker-entrypoint-initdb.d/woebegon-data.sql

# Copy the pre-configured Tomcat (with the deployed UniTime webapp) into the image
COPY apache-tomcat-9.0.82 /usr/local/tomcat

# Create a non-root user for Tomcat
RUN groupadd -r tomcat && \
    useradd -r -g tomcat -d /usr/local/tomcat -s /bin/false tomcat && \
    chown -R tomcat: /usr/local/tomcat

# Set environment variables for Tomcat
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
ENV JAVA_OPTS "-Djava.awt.headless=true -Xmx2048m -XX:+UseG1GC"

# Expose the port Tomcat will run on
EXPOSE 8080

# Copy entrypoint script into the image
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use the entrypoint script to start services
ENTRYPOINT ["/entrypoint.sh"]
