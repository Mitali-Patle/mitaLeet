import { useState, useEffect } from 'react';
import './popup.css';

const API_BASE = process.env.PLASMO_PUBLIC_API_URL ?? 'http://localhost:3000';

interface AuthState {
  isLinked: boolean;
  token: string;
  username?: string;
}

function Popup() {
  const [state, setState] = useState<AuthState>({ isLinked: false, token: '' });
  const [token, setToken] = useState('');
  const [loading, setLoading] = useState(false);
  const [statusMsg, setStatusMsg] = useState('');

  useEffect(() => {
    chrome.storage.local.get(['lc_token', 'lc_username'], (data) => {
      if (data.lc_token) {
        setState({ isLinked: true, token: data.lc_token, username: data.lc_username });
      }
    });
  }, []);

  const handleLink = async () => {
    if (!token.trim()) return;
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/api/v1/users/me`, {
        headers: { Authorization: `Bearer ${token.trim()}` },
      });
      if (!res.ok) throw new Error('Invalid token');
      const data = await res.json();
      await chrome.storage.local.set({
        lc_token: token.trim(),
        lc_userId: data.data?.id,
        lc_username: data.data?.displayName,
      });
      setState({ isLinked: true, token: token.trim(), username: data.data?.displayName });
      setStatusMsg('Linked successfully');
    } catch {
      setStatusMsg('Invalid token. Get yours from mitaLeet app settings.');
    } finally {
      setLoading(false);
    }
  };

  const handleUnlink = async () => {
    await chrome.storage.local.remove(['lc_token', 'lc_userId', 'lc_username']);
    setState({ isLinked: false, token: '' });
    setToken('');
  };

  return (
    <div className="popup">
      <div className="header">
        <div className="logo">LC</div>
        <div>
          <div className="title">mitaLeet</div>
          <div className="subtitle">SOLVE TRACKER</div>
        </div>
      </div>

      {state.isLinked ? (
        <div className="linked">
          <div className="status-dot active" />
          <div>
            <div className="username">@{state.username}</div>
            <div className="linked-label">TRACKING ACTIVE</div>
          </div>
          <button className="unlink-btn" onClick={handleUnlink}>UNLINK</button>
        </div>
      ) : (
        <div className="form">
          <div className="field-label">API TOKEN</div>
          <input
            className="input"
            type="password"
            placeholder="Paste from mitaLeet app"
            value={token}
            onChange={(e) => setToken(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLink()}
          />
          <button className="link-btn" onClick={handleLink} disabled={loading}>
            {loading ? 'VERIFYING...' : 'LINK ACCOUNT'}
          </button>
          {statusMsg && <div className="status-msg">{statusMsg}</div>}
        </div>
      )}

      <div className="footer">
        <span>TRACKING</span>
        <span className="dot" />
        <span>leetcode.com</span>
      </div>
    </div>
  );
}

export default Popup;
