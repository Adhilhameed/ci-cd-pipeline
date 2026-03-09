import React, { useState } from 'react';

function App() {
  const [count, setCount] = useState(0);

  return (
    <div className="App">
      <header className="App-header">
        <h1>CI/CD Pipeline Demo App V2</h1>
        <p>Deployed via Jenkins → Docker → AWS</p>
        <p>Build #{process.env.REACT_APP_BUILD_NUMBER || 'local'}</p>
        <button onClick={() => setCount(count + 1)}>
          Clicked {count} times
        </button>
      </header>
    </div>
  );
}

export default App;
