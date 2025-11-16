#!/usr/bin/env python3
"""
Automated Database Backup Script for GentleQuest
Supports local and cloud backups with encryption
"""

import os
import sys
import json
import gzip
import hashlib
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
import boto3
import psycopg
from cryptography.fernet import Fernet
from typing import Optional, Dict, List
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DatabaseBackup:
    def __init__(self, config_path: str = ".env"):
        """Initialize backup system with configuration"""
        self.config = self._load_config(config_path)
        self.backup_dir = Path(self.config.get('BACKUP_DIR', './backups'))
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize encryption if key provided
        self.cipher = None
        if self.config.get('BACKUP_ENCRYPTION_KEY'):
            self.cipher = Fernet(self.config['BACKUP_ENCRYPTION_KEY'].encode())
            
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from environment or file"""
        config = {}
        
        # Load from .env file
        if Path(config_path).exists():
            with open(config_path) as f:
                for line in f:
                    if '=' in line and not line.startswith('#'):
                        key, value = line.strip().split('=', 1)
                        config[key] = value.strip('"\'')
                        
        # Override with environment variables
        config.update({
            'DATABASE_URL': os.getenv('DATABASE_URL', config.get('DATABASE_URL')),
            'BACKUP_S3_BUCKET': os.getenv('BACKUP_S3_BUCKET', config.get('BACKUP_S3_BUCKET')),
            'BACKUP_RETENTION_DAYS': int(os.getenv('BACKUP_RETENTION_DAYS', config.get('BACKUP_RETENTION_DAYS', 30))),
            'BACKUP_ENCRYPTION_KEY': os.getenv('BACKUP_ENCRYPTION_KEY', config.get('BACKUP_ENCRYPTION_KEY')),
            'AWS_ACCESS_KEY_ID': os.getenv('AWS_ACCESS_KEY_ID', config.get('AWS_ACCESS_KEY_ID')),
            'AWS_SECRET_ACCESS_KEY': os.getenv('AWS_SECRET_ACCESS_KEY', config.get('AWS_SECRET_ACCESS_KEY')),
            'AWS_REGION': os.getenv('AWS_REGION', config.get('AWS_REGION', 'us-east-1')),
        })
        
        return config
        
    def backup_database(self) -> Optional[Path]:
        """Create database backup using pg_dump"""
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        backup_file = self.backup_dir / f"gentlequest_backup_{timestamp}.sql"
        
        try:
            # Parse database URL
            db_url = self.config['DATABASE_URL']
            
            # Use pg_dump for backup
            logger.info(f"Starting database backup to {backup_file}")
            
            with open(backup_file, 'w') as f:
                result = subprocess.run(
                    ['pg_dump', db_url, '--no-owner', '--no-acl'],
                    stdout=f,
                    stderr=subprocess.PIPE,
                    text=True,
                    check=True
                )
                
            logger.info(f"Database backup completed: {backup_file}")
            
            # Compress the backup
            compressed_file = self._compress_backup(backup_file)
            
            # Encrypt if configured
            if self.cipher:
                encrypted_file = self._encrypt_backup(compressed_file)
                compressed_file.unlink()  # Remove unencrypted version
                return encrypted_file
                
            return compressed_file
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Database backup failed: {e.stderr}")
            if backup_file.exists():
                backup_file.unlink()
            return None
        except Exception as e:
            logger.error(f"Backup error: {e}")
            return None
            
    def _compress_backup(self, backup_file: Path) -> Path:
        """Compress backup file using gzip"""
        compressed_file = backup_file.with_suffix('.sql.gz')
        
        logger.info(f"Compressing backup to {compressed_file}")
        
        with open(backup_file, 'rb') as f_in:
            with gzip.open(compressed_file, 'wb', compresslevel=9) as f_out:
                f_out.writelines(f_in)
                
        # Remove original file
        backup_file.unlink()
        
        # Calculate and log compression ratio
        compressed_size = compressed_file.stat().st_size
        logger.info(f"Backup compressed to {compressed_size / 1024 / 1024:.2f} MB")
        
        return compressed_file
        
    def _encrypt_backup(self, backup_file: Path) -> Path:
        """Encrypt backup file"""
        encrypted_file = backup_file.with_suffix(backup_file.suffix + '.enc')
        
        logger.info(f"Encrypting backup to {encrypted_file}")
        
        with open(backup_file, 'rb') as f_in:
            encrypted_data = self.cipher.encrypt(f_in.read())
            
        with open(encrypted_file, 'wb') as f_out:
            f_out.write(encrypted_data)
            
        logger.info("Backup encrypted successfully")
        return encrypted_file
        
    def upload_to_s3(self, backup_file: Path) -> bool:
        """Upload backup to S3"""
        if not self.config.get('BACKUP_S3_BUCKET'):
            logger.warning("S3 bucket not configured, skipping cloud upload")
            return False
            
        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=self.config.get('AWS_ACCESS_KEY_ID'),
                aws_secret_access_key=self.config.get('AWS_SECRET_ACCESS_KEY'),
                region_name=self.config.get('AWS_REGION')
            )
            
            s3_key = f"database-backups/{backup_file.name}"
            
            logger.info(f"Uploading backup to S3: s3://{self.config['BACKUP_S3_BUCKET']}/{s3_key}")
            
            # Calculate checksum
            with open(backup_file, 'rb') as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()
            
            # Upload with metadata
            s3_client.upload_file(
                str(backup_file),
                self.config['BACKUP_S3_BUCKET'],
                s3_key,
                ExtraArgs={
                    'Metadata': {
                        'timestamp': datetime.utcnow().isoformat(),
                        'sha256': file_hash,
                        'encrypted': 'true' if backup_file.suffix.endswith('.enc') else 'false'
                    },
                    'ServerSideEncryption': 'AES256'
                }
            )
            
            logger.info("Backup uploaded to S3 successfully")
            return True
            
        except Exception as e:
            logger.error(f"S3 upload failed: {e}")
            return False
            
    def cleanup_old_backups(self):
        """Remove old local and S3 backups based on retention policy"""
        retention_days = self.config.get('BACKUP_RETENTION_DAYS', 30)
        cutoff_date = datetime.utcnow() - timedelta(days=retention_days)
        
        # Clean local backups
        logger.info(f"Cleaning backups older than {retention_days} days")
        
        for backup_file in self.backup_dir.glob('gentlequest_backup_*.sql*'):
            # Parse timestamp from filename
            try:
                timestamp_str = backup_file.name.split('_')[2] + '_' + backup_file.name.split('_')[3].split('.')[0]
                file_date = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                
                if file_date < cutoff_date:
                    logger.info(f"Removing old backup: {backup_file}")
                    backup_file.unlink()
            except Exception as e:
                logger.warning(f"Could not parse date from {backup_file}: {e}")
                
        # Clean S3 backups
        if self.config.get('BACKUP_S3_BUCKET'):
            self._cleanup_s3_backups(cutoff_date)
            
    def _cleanup_s3_backups(self, cutoff_date: datetime):
        """Clean old backups from S3"""
        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=self.config.get('AWS_ACCESS_KEY_ID'),
                aws_secret_access_key=self.config.get('AWS_SECRET_ACCESS_KEY'),
                region_name=self.config.get('AWS_REGION')
            )
            
            response = s3_client.list_objects_v2(
                Bucket=self.config['BACKUP_S3_BUCKET'],
                Prefix='database-backups/'
            )
            
            if 'Contents' not in response:
                return
                
            for obj in response['Contents']:
                if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
                    logger.info(f"Removing old S3 backup: {obj['Key']}")
                    s3_client.delete_object(
                        Bucket=self.config['BACKUP_S3_BUCKET'],
                        Key=obj['Key']
                    )
                    
        except Exception as e:
            logger.error(f"S3 cleanup failed: {e}")
            
    def restore_database(self, backup_file: Path, target_db: Optional[str] = None) -> bool:
        """Restore database from backup file"""
        try:
            # Decrypt if necessary
            if backup_file.suffix.endswith('.enc'):
                if not self.cipher:
                    logger.error("Cannot decrypt backup: encryption key not configured")
                    return False
                backup_file = self._decrypt_backup(backup_file)
                
            # Decompress if necessary
            if backup_file.suffix.endswith('.gz'):
                backup_file = self._decompress_backup(backup_file)
                
            # Restore using pg_restore or psql
            target_url = target_db or self.config['DATABASE_URL']
            
            logger.info(f"Restoring database from {backup_file}")
            
            result = subprocess.run(
                ['psql', target_url, '-f', str(backup_file)],
                capture_output=True,
                text=True,
                check=True
            )
            
            logger.info("Database restored successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Database restore failed: {e.stderr}")
            return False
        except Exception as e:
            logger.error(f"Restore error: {e}")
            return False
            
    def _decrypt_backup(self, backup_file: Path) -> Path:
        """Decrypt backup file"""
        decrypted_file = backup_file.with_suffix('')
        
        logger.info(f"Decrypting backup to {decrypted_file}")
        
        with open(backup_file, 'rb') as f_in:
            decrypted_data = self.cipher.decrypt(f_in.read())
            
        with open(decrypted_file, 'wb') as f_out:
            f_out.write(decrypted_data)
            
        return decrypted_file
        
    def _decompress_backup(self, backup_file: Path) -> Path:
        """Decompress backup file"""
        decompressed_file = backup_file.with_suffix('')
        
        logger.info(f"Decompressing backup to {decompressed_file}")
        
        with gzip.open(backup_file, 'rb') as f_in:
            with open(decompressed_file, 'wb') as f_out:
                f_out.write(f_in.read())
                
        return decompressed_file
        
    def get_backup_status(self) -> Dict:
        """Get status of backups"""
        local_backups = list(self.backup_dir.glob('gentlequest_backup_*.sql*'))
        
        status = {
            'local_backups': len(local_backups),
            'latest_backup': None,
            'total_size_mb': 0,
            's3_configured': bool(self.config.get('BACKUP_S3_BUCKET')),
            'encryption_enabled': bool(self.cipher)
        }
        
        if local_backups:
            latest = max(local_backups, key=lambda p: p.stat().st_mtime)
            status['latest_backup'] = {
                'file': latest.name,
                'size_mb': latest.stat().st_size / 1024 / 1024,
                'created': datetime.fromtimestamp(latest.stat().st_mtime).isoformat()
            }
            status['total_size_mb'] = sum(f.stat().st_size for f in local_backups) / 1024 / 1024
            
        return status


def main():
    """Main function for command-line usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='GentleQuest Database Backup Manager')
    parser.add_argument('action', choices=['backup', 'restore', 'cleanup', 'status'],
                       help='Action to perform')
    parser.add_argument('--file', help='Backup file for restore operation')
    parser.add_argument('--target-db', help='Target database URL for restore')
    parser.add_argument('--config', default='.env', help='Configuration file path')
    parser.add_argument('--upload', action='store_true', help='Upload backup to S3')
    
    args = parser.parse_args()
    
    backup_manager = DatabaseBackup(args.config)
    
    if args.action == 'backup':
        backup_file = backup_manager.backup_database()
        if backup_file:
            logger.info(f"Backup created: {backup_file}")
            if args.upload:
                if backup_manager.upload_to_s3(backup_file):
                    logger.info("Backup uploaded to cloud storage")
            backup_manager.cleanup_old_backups()
        else:
            logger.error("Backup failed")
            sys.exit(1)
            
    elif args.action == 'restore':
        if not args.file:
            logger.error("--file required for restore operation")
            sys.exit(1)
        backup_file = Path(args.file)
        if not backup_file.exists():
            logger.error(f"Backup file not found: {backup_file}")
            sys.exit(1)
        if backup_manager.restore_database(backup_file, args.target_db):
            logger.info("Database restored successfully")
        else:
            logger.error("Restore failed")
            sys.exit(1)
            
    elif args.action == 'cleanup':
        backup_manager.cleanup_old_backups()
        logger.info("Cleanup completed")
        
    elif args.action == 'status':
        status = backup_manager.get_backup_status()
        print(json.dumps(status, indent=2))


if __name__ == '__main__':
    main()
