import { render, screen, fireEvent } from '@testing-library/react';
import App from './App';

describe('App Component', () => {
  test('renders app title', () => {
    render(<App />);
    expect(screen.getByText(/CI\/CD Pipeline Demo App/i)).toBeInTheDocument();
  });

  test('renders deployment info', () => {
    render(<App />);
    expect(screen.getByText(/Deployed via Jenkins/i)).toBeInTheDocument();
  });

  test('counter starts at zero', () => {
    render(<App />);
    expect(screen.getByText(/Clicked 0 times/i)).toBeInTheDocument();
  });

  test('counter increments on button click', () => {
    render(<App />);
    const button = screen.getByRole('button');
    fireEvent.click(button);
    expect(screen.getByText(/Clicked 1 times/i)).toBeInTheDocument();
  });

  test('counter increments multiple times', () => {
    render(<App />);
    const button = screen.getByRole('button');
    fireEvent.click(button);
    fireEvent.click(button);
    fireEvent.click(button);
    expect(screen.getByText(/Clicked 3 times/i)).toBeInTheDocument();
  });
});
