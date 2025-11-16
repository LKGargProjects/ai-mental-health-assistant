#!/usr/bin/env python3
"""
Monitoring and Alerting System for GentleQuest
Integrates with various monitoring services
"""

import os
import time
import json
import requests
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AlertSeverity(Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


@dataclass
class HealthCheck:
    """Health check configuration"""
    name: str
    url: str
    expected_status: int = 200
    timeout: int = 10
    check_interval: int = 60
    failure_threshold: int = 3
    success_threshold: int = 2


@dataclass
class Alert:
    """Alert data"""
    service: str
    severity: AlertSeverity
    message: str
    timestamp: datetime
    metadata: Dict = None


class MonitoringService:
    """Main monitoring service"""
    
    def __init__(self, config_file: str = "monitoring_config.json"):
        self.config = self._load_config(config_file)
        self.health_checks = self._init_health_checks()
        self.alert_channels = self._init_alert_channels()
        self.metrics_storage = []
        self.failure_counts = {}
        self.last_alert_times = {}
        
    def _load_config(self, config_file: str) -> Dict:
        """Load monitoring configuration"""
        config = {
            'base_url': os.getenv('MONITORING_BASE_URL', 'https://gentlequest.onrender.com'),
            'alert_email': os.getenv('ALERT_EMAIL'),
            'slack_webhook': os.getenv('SLACK_WEBHOOK_URL'),
            'discord_webhook': os.getenv('DISCORD_WEBHOOK_URL'),
            'pagerduty_key': os.getenv('PAGERDUTY_INTEGRATION_KEY'),
            'smtp_host': os.getenv('SMTP_HOST', 'smtp.gmail.com'),
            'smtp_port': int(os.getenv('SMTP_PORT', 587)),
            'smtp_username': os.getenv('SMTP_USERNAME'),
            'smtp_password': os.getenv('SMTP_PASSWORD'),
            'alert_cooldown_minutes': int(os.getenv('ALERT_COOLDOWN_MINUTES', 15)),
        }
        
        # Load from file if exists
        if os.path.exists(config_file):
            with open(config_file) as f:
                file_config = json.load(f)
                config.update(file_config)
                
        return config
        
    def _init_health_checks(self) -> List[HealthCheck]:
        """Initialize health check configurations"""
        base_url = self.config['base_url']
        
        return [
            HealthCheck(
                name="API Health",
                url=f"{base_url}/api/health",
                expected_status=200,
                timeout=10,
                check_interval=60
            ),
            HealthCheck(
                name="API Ping",
                url=f"{base_url}/api/ping",
                expected_status=200,
                timeout=5,
                check_interval=30
            ),
            HealthCheck(
                name="Chat Endpoint",
                url=f"{base_url}/api/chat",
                expected_status=405,  # GET not allowed
                timeout=10,
                check_interval=120
            ),
            HealthCheck(
                name="Metrics",
                url=f"{base_url}/api/metrics",
                expected_status=200,
                timeout=10,
                check_interval=300
            ),
            HealthCheck(
                name="Community Feed",
                url=f"{base_url}/api/community/feed?limit=1",
                expected_status=200,
                timeout=10,
                check_interval=180
            ),
        ]
        
    def _init_alert_channels(self) -> Dict:
        """Initialize alert channels"""
        channels = {}
        
        if self.config.get('alert_email'):
            channels['email'] = self._send_email_alert
            
        if self.config.get('slack_webhook'):
            channels['slack'] = self._send_slack_alert
            
        if self.config.get('discord_webhook'):
            channels['discord'] = self._send_discord_alert
            
        if self.config.get('pagerduty_key'):
            channels['pagerduty'] = self._send_pagerduty_alert
            
        return channels
        
    def perform_health_check(self, check: HealthCheck) -> Tuple[bool, Dict]:
        """Perform a single health check"""
        start_time = time.time()
        
        try:
            response = requests.get(
                check.url,
                timeout=check.timeout,
                headers={'User-Agent': 'GentleQuest-Monitor/1.0'}
            )
            
            elapsed_ms = int((time.time() - start_time) * 1000)
            
            result = {
                'name': check.name,
                'url': check.url,
                'status_code': response.status_code,
                'response_time_ms': elapsed_ms,
                'timestamp': datetime.utcnow().isoformat(),
                'success': response.status_code == check.expected_status
            }
            
            # Parse health data if available
            if check.name == "API Health" and response.status_code == 200:
                try:
                    health_data = response.json()
                    result['health_data'] = {
                        'status': health_data.get('status'),
                        'database': health_data.get('database'),
                        'redis': health_data.get('redis'),
                        'environment': health_data.get('environment')
                    }
                except:
                    pass
                    
            return result['success'], result
            
        except requests.RequestException as e:
            elapsed_ms = int((time.time() - start_time) * 1000)
            
            result = {
                'name': check.name,
                'url': check.url,
                'error': str(e),
                'response_time_ms': elapsed_ms,
                'timestamp': datetime.utcnow().isoformat(),
                'success': False
            }
            
            return False, result
            
    def check_all_services(self) -> Dict:
        """Check all configured services"""
        results = []
        all_healthy = True
        
        for check in self.health_checks:
            success, result = self.perform_health_check(check)
            results.append(result)
            
            if not success:
                all_healthy = False
                self._handle_failure(check, result)
            else:
                self._handle_success(check, result)
                
        summary = {
            'timestamp': datetime.utcnow().isoformat(),
            'all_healthy': all_healthy,
            'checks_performed': len(results),
            'failures': sum(1 for r in results if not r['success']),
            'results': results
        }
        
        # Store metrics
        self.metrics_storage.append(summary)
        
        # Trim old metrics (keep last 1000)
        if len(self.metrics_storage) > 1000:
            self.metrics_storage = self.metrics_storage[-1000:]
            
        return summary
        
    def _handle_failure(self, check: HealthCheck, result: Dict):
        """Handle health check failure"""
        failure_key = check.name
        
        # Increment failure counter
        self.failure_counts[failure_key] = self.failure_counts.get(failure_key, 0) + 1
        
        # Check if threshold exceeded
        if self.failure_counts[failure_key] >= check.failure_threshold:
            # Determine severity based on failure count
            if self.failure_counts[failure_key] >= check.failure_threshold * 3:
                severity = AlertSeverity.CRITICAL
            elif self.failure_counts[failure_key] >= check.failure_threshold * 2:
                severity = AlertSeverity.ERROR
            else:
                severity = AlertSeverity.WARNING
                
            # Create alert
            alert = Alert(
                service=check.name,
                severity=severity,
                message=f"Health check failed: {check.name} - {result.get('error', f'Status {result.get('status_code')}')}",
                timestamp=datetime.utcnow(),
                metadata=result
            )
            
            # Send alert if not in cooldown
            self._send_alert(alert)
            
    def _handle_success(self, check: HealthCheck, result: Dict):
        """Handle health check success"""
        failure_key = check.name
        
        # Reset failure counter on success
        if failure_key in self.failure_counts:
            if self.failure_counts[failure_key] >= check.failure_threshold:
                # Service recovered - send recovery alert
                alert = Alert(
                    service=check.name,
                    severity=AlertSeverity.INFO,
                    message=f"Service recovered: {check.name}",
                    timestamp=datetime.utcnow(),
                    metadata=result
                )
                self._send_alert(alert)
                
            self.failure_counts[failure_key] = 0
            
    def _send_alert(self, alert: Alert):
        """Send alert through configured channels"""
        alert_key = f"{alert.service}:{alert.severity.value}"
        
        # Check cooldown
        if alert_key in self.last_alert_times:
            last_alert = self.last_alert_times[alert_key]
            cooldown = timedelta(minutes=self.config.get('alert_cooldown_minutes', 15))
            
            if datetime.utcnow() - last_alert < cooldown:
                logger.info(f"Alert suppressed due to cooldown: {alert_key}")
                return
                
        # Send through all configured channels
        for channel_name, channel_func in self.alert_channels.items():
            try:
                channel_func(alert)
                logger.info(f"Alert sent via {channel_name}: {alert.message}")
            except Exception as e:
                logger.error(f"Failed to send alert via {channel_name}: {e}")
                
        # Update last alert time
        self.last_alert_times[alert_key] = datetime.utcnow()
        
    def _send_email_alert(self, alert: Alert):
        """Send email alert"""
        if not self.config.get('smtp_username'):
            return
            
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"[{alert.severity.value.upper()}] GentleQuest Alert: {alert.service}"
        msg['From'] = self.config['smtp_username']
        msg['To'] = self.config['alert_email']
        
        # Create HTML body
        html_body = f"""
        <html>
        <body>
            <h2 style="color: {'red' if alert.severity == AlertSeverity.CRITICAL else 'orange'};">
                {alert.severity.value.upper()}: {alert.service}
            </h2>
            <p><strong>Message:</strong> {alert.message}</p>
            <p><strong>Time:</strong> {alert.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
            
            {f'<pre>{json.dumps(alert.metadata, indent=2)}</pre>' if alert.metadata else ''}
            
            <hr>
            <p><small>This is an automated alert from GentleQuest Monitoring</small></p>
        </body>
        </html>
        """
        
        msg.attach(MIMEText(html_body, 'html'))
        
        # Send email
        with smtplib.SMTP(self.config['smtp_host'], self.config['smtp_port']) as server:
            server.starttls()
            server.login(self.config['smtp_username'], self.config['smtp_password'])
            server.send_message(msg)
            
    def _send_slack_alert(self, alert: Alert):
        """Send Slack alert"""
        emoji = {
            AlertSeverity.INFO: ":information_source:",
            AlertSeverity.WARNING: ":warning:",
            AlertSeverity.ERROR: ":x:",
            AlertSeverity.CRITICAL: ":rotating_light:"
        }
        
        payload = {
            "text": f"{emoji[alert.severity]} *{alert.severity.value.upper()}*: {alert.service}",
            "attachments": [{
                "color": {
                    AlertSeverity.INFO: "good",
                    AlertSeverity.WARNING: "warning",
                    AlertSeverity.ERROR: "danger",
                    AlertSeverity.CRITICAL: "danger"
                }[alert.severity],
                "fields": [
                    {"title": "Service", "value": alert.service, "short": True},
                    {"title": "Severity", "value": alert.severity.value, "short": True},
                    {"title": "Message", "value": alert.message, "short": False},
                    {"title": "Time", "value": alert.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC'), "short": True}
                ]
            }]
        }
        
        requests.post(self.config['slack_webhook'], json=payload)
        
    def _send_discord_alert(self, alert: Alert):
        """Send Discord alert"""
        color = {
            AlertSeverity.INFO: 0x00FF00,
            AlertSeverity.WARNING: 0xFFFF00,
            AlertSeverity.ERROR: 0xFF0000,
            AlertSeverity.CRITICAL: 0x8B0000
        }
        
        payload = {
            "embeds": [{
                "title": f"{alert.severity.value.upper()}: {alert.service}",
                "description": alert.message,
                "color": color[alert.severity],
                "fields": [
                    {"name": "Service", "value": alert.service, "inline": True},
                    {"name": "Severity", "value": alert.severity.value, "inline": True},
                    {"name": "Time", "value": alert.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC'), "inline": False}
                ],
                "timestamp": alert.timestamp.isoformat()
            }]
        }
        
        requests.post(self.config['discord_webhook'], json=payload)
        
    def _send_pagerduty_alert(self, alert: Alert):
        """Send PagerDuty alert"""
        payload = {
            "routing_key": self.config['pagerduty_key'],
            "event_action": "trigger" if alert.severity in [AlertSeverity.ERROR, AlertSeverity.CRITICAL] else "resolve",
            "payload": {
                "summary": f"{alert.service}: {alert.message}",
                "severity": {
                    AlertSeverity.INFO: "info",
                    AlertSeverity.WARNING: "warning",
                    AlertSeverity.ERROR: "error",
                    AlertSeverity.CRITICAL: "critical"
                }[alert.severity],
                "source": "GentleQuest Monitor",
                "timestamp": alert.timestamp.isoformat(),
                "custom_details": alert.metadata
            }
        }
        
        requests.post('https://events.pagerduty.com/v2/enqueue', json=payload)
        
    def get_uptime_stats(self) -> Dict:
        """Calculate uptime statistics"""
        if not self.metrics_storage:
            return {
                'uptime_percentage': 0,
                'total_checks': 0,
                'successful_checks': 0,
                'failed_checks': 0
            }
            
        total_checks = 0
        successful_checks = 0
        
        for summary in self.metrics_storage:
            for result in summary['results']:
                total_checks += 1
                if result['success']:
                    successful_checks += 1
                    
        uptime_percentage = (successful_checks / total_checks * 100) if total_checks > 0 else 0
        
        return {
            'uptime_percentage': round(uptime_percentage, 2),
            'total_checks': total_checks,
            'successful_checks': successful_checks,
            'failed_checks': total_checks - successful_checks,
            'monitoring_duration_hours': len(self.metrics_storage) / 60
        }
        
    def generate_report(self) -> str:
        """Generate monitoring report"""
        stats = self.get_uptime_stats()
        
        report = f"""
# GentleQuest Monitoring Report
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}

## Uptime Statistics
- Overall Uptime: {stats['uptime_percentage']}%
- Total Checks: {stats['total_checks']}
- Successful: {stats['successful_checks']}
- Failed: {stats['failed_checks']}
- Monitoring Duration: {stats['monitoring_duration_hours']:.1f} hours

## Service Status
"""
        
        # Add per-service status
        service_stats = {}
        for summary in self.metrics_storage[-100:]:  # Last 100 checks
            for result in summary['results']:
                name = result['name']
                if name not in service_stats:
                    service_stats[name] = {'success': 0, 'failure': 0, 'response_times': []}
                    
                if result['success']:
                    service_stats[name]['success'] += 1
                else:
                    service_stats[name]['failure'] += 1
                    
                if 'response_time_ms' in result:
                    service_stats[name]['response_times'].append(result['response_time_ms'])
                    
        for service, stats in service_stats.items():
            total = stats['success'] + stats['failure']
            uptime = (stats['success'] / total * 100) if total > 0 else 0
            avg_response = sum(stats['response_times']) / len(stats['response_times']) if stats['response_times'] else 0
            
            report += f"""
### {service}
- Uptime: {uptime:.1f}%
- Avg Response Time: {avg_response:.0f}ms
- Checks: {total} (Success: {stats['success']}, Failed: {stats['failure']})
"""
        
        return report


def run_monitoring_daemon():
    """Run monitoring as a daemon"""
    monitor = MonitoringService()
    
    logger.info("Starting GentleQuest Monitoring Daemon")
    logger.info(f"Monitoring {len(monitor.health_checks)} services")
    logger.info(f"Alert channels: {list(monitor.alert_channels.keys())}")
    
    while True:
        try:
            # Perform health checks
            summary = monitor.check_all_services()
            
            # Log summary
            logger.info(f"Health check complete - Healthy: {summary['all_healthy']}, "
                       f"Failures: {summary['failures']}/{summary['checks_performed']}")
            
            # Generate and log report every hour
            if len(monitor.metrics_storage) % 60 == 0:
                report = monitor.generate_report()
                logger.info(report)
                
                # Send report as info alert
                if monitor.alert_channels:
                    alert = Alert(
                        service="Monitoring Report",
                        severity=AlertSeverity.INFO,
                        message=f"Hourly report - Uptime: {monitor.get_uptime_stats()['uptime_percentage']}%",
                        timestamp=datetime.utcnow(),
                        metadata={'report': report}
                    )
                    monitor._send_alert(alert)
                    
        except Exception as e:
            logger.error(f"Monitoring error: {e}")
            
        # Wait before next check cycle
        time.sleep(60)


if __name__ == '__main__':
    run_monitoring_daemon()
